require "prism"
require "open3"
require "ctxpack/default_constant_resolver"
require "ctxpack/packet"

module Ctxpack
  class Compiler
    LIMITS = {
      max_total_files: 8,
      max_constant_files: 4,
      max_view_files: 2,
      max_test_files: 2,
      max_snippet_lines_per_file: 120
    }.freeze

    CALLBACK_DECLARATIONS = %i[before_action prepend_before_action append_before_action].freeze
    AROUND_DECLARATIONS = %i[around_action].freeze
    IGNORED_DECLARATIONS = %i[after_action].freeze
    DYNAMIC_DISPATCH_CALLS = %w[__send__ alias_method method public_send send].freeze

    CallbackDeclaration = Struct.new(:kind, :names, :applies, :dynamic, :block, :node, keyword_init: true)
    ParsedAnchor = Struct.new(:controller_path, :action, keyword_init: true)

    def initialize(app_root:, anchor:, task:, constant_resolver: nil)
      @app_root = File.expand_path(app_root)
      @anchor = anchor
      @task = task
      @constant_resolver = constant_resolver || DefaultConstantResolver.new(app_root: @app_root)
    end

    def compile
      parsed_anchor = parse_anchor(@anchor)
      controller_relative_path = controller_file_path(parsed_anchor.controller_path)
      controller_absolute_path = File.join(@app_root, controller_relative_path)

      unless File.file?(controller_absolute_path)
        raise Error, "expected controller file does not exist: #{controller_relative_path}"
      end

      source = File.read(controller_absolute_path)
      program = parse_ruby(source, controller_relative_path)
      controller_class_info = find_controller_class(program, parsed_anchor.controller_path, controller_relative_path)
      controller_name = controller_class_info.fetch(:name)
      controller_class = controller_class_info.fetch(:node)
      methods = direct_methods(controller_class)
      action_node = methods[parsed_anchor.action]

      unless action_node
        raise Error, "action #{parsed_anchor.action} was not directly defined in #{controller_relative_path}; inherited, concern-defined, and metaprogrammed actions are unsupported in v0"
      end

      packet = Packet.new(
        anchor: @anchor,
        task: @task,
        repo: repo_stamp,
        app_root: @app_root,
        entrypoint: Entrypoint.new(
          file: controller_relative_path,
          controller: controller_name,
          action: parsed_anchor.action
        )
      )

      callbacks = applicable_callbacks(controller_class, parsed_anchor.action, packet)
      add_controller_evidence(packet, controller_relative_path, action_node, callbacks, methods)
      add_view_candidates(packet, parsed_anchor.controller_path, parsed_anchor.action)
      add_constant_evidence(packet, action_node, callbacks, methods, controller_name)
      add_test_candidates(packet, parsed_anchor.controller_path, parsed_anchor.action)
      enforce_total_file_limit(packet)

      packet
    end

    private

    def parse_anchor(anchor)
      unless anchor.match?(/\A[a-z][a-z0-9_]*(?:\/[a-z][a-z0-9_]*)*#_?[a-z][a-z0-9_]*[?!]?\z/)
        raise Error, "invalid anchor #{anchor.inspect}; expected controller#action with snake_case tokens"
      end

      controller_path, action = anchor.split("#", 2)
      ParsedAnchor.new(controller_path: controller_path, action: action)
    end

    def controller_file_path(controller_path)
      File.join("app", "controllers", "#{controller_path}_controller.rb").tr(File::SEPARATOR, "/")
    end

    def parse_ruby(source, path)
      result = Prism.parse(source)
      if result.failure?
        raise Error, "failed to parse #{path} with Prism: #{result.errors.map(&:message).join(", ")}"
      end

      result.value
    end

    def find_controller_class(program, controller_path, relative_path)
      expected_segments = controller_path.split("/").map { |segment| segment.delete("_") }
      find_classes(program).find { |class_info| controller_class_match?(class_info.fetch(:name), expected_segments) } ||
        raise(Error, "no controller class matching #{controller_path} was defined in #{relative_path}")
    end

    def controller_class_match?(class_name, expected_segments)
      segments = class_name.delete_prefix("::").split("::")
      return false unless segments.length == expected_segments.length
      return false unless segments.last.end_with?("Controller")

      normalized = segments[0...-1] + [segments.last.delete_suffix("Controller")]
      normalized.map { |segment| segment.downcase.delete("_") } == expected_segments
    end

    def find_classes(node, namespace = [])
      classes = []
      return classes unless node.respond_to?(:child_nodes)

      if node.is_a?(Prism::ModuleNode)
        module_name = constant_name(node.constant_path)
        nested_namespace = qualified_name(module_name, namespace).split("::")
        child_nodes(node).each { |child| classes.concat(find_classes(child, nested_namespace)) }
        return classes
      end

      if node.is_a?(Prism::ClassNode)
        class_name = constant_name(node.constant_path)
        full_name = qualified_name(class_name, namespace)
        classes << { name: full_name, node: node }
        child_nodes(node).each { |child| classes.concat(find_classes(child, full_name.split("::"))) }
        return classes
      end

      child_nodes(node).each { |child| classes.concat(find_classes(child, namespace)) }
      classes
    end

    def qualified_name(name, namespace)
      return name if root_qualified_constant?(name) || name.include?("::") || namespace.empty?

      (namespace + [name]).join("::")
    end

    def direct_methods(class_node)
      body_statements(class_node).each_with_object({}) do |node, methods|
        direct_method_nodes(node).each do |method_node|
          methods[method_node.name.to_s] = method_node
        end
      end
    end

    def direct_method_nodes(node)
      return [node] if node.is_a?(Prism::DefNode) && node.receiver.nil?
      return [] unless inline_visibility_call?(node)

      (node.arguments&.arguments || []).select do |argument|
        argument.is_a?(Prism::DefNode) && argument.receiver.nil?
      end
    end

    def inline_visibility_call?(node)
      node.is_a?(Prism::CallNode) &&
        node.receiver.nil? &&
        %i[private protected public].include?(node.name)
    end

    def body_statements(node)
      statements = node.respond_to?(:body) ? node.body : nil
      return [] unless statements.respond_to?(:body)

      statements.body
    end

    def applicable_callbacks(controller_class, action, packet)
      declarations = callback_declarations(controller_class, action)
      skips = declarations.select { |declaration| declaration.kind == :skip_before_action }

      skipped_names = []
      skips.each do |skip|
        if skip.dynamic
          packet.add_uncertainty(
            code: "dynamic_callback_args",
            subject: callback_uncertainty_subject(skip),
            message: "skip_before_action used dynamic callback arguments"
          )
          next
        end

        skipped_names.concat(skip.names) if skip.applies
      end

      declarations.each_with_object([]) do |declaration, applicable|
        next if IGNORED_DECLARATIONS.include?(declaration.kind)
        next if declaration.kind == :skip_before_action

        if declaration.dynamic
          packet.add_uncertainty(
            code: "dynamic_callback_args",
            subject: callback_uncertainty_subject(declaration),
            message: "#{declaration.kind} used dynamic callback arguments"
          )
          next
        end

        next unless declaration.applies

        if declaration.block
          packet.add_uncertainty(
            code: "block_callback_present",
            subject: declaration.kind.to_s,
            message: "inline callback block applies to #{action}"
          )
          next
        end

        if AROUND_DECLARATIONS.include?(declaration.kind)
          declaration.names.each do |name|
            packet.add_uncertainty(
              code: "around_callback_present",
              subject: name,
              message: "around_action #{name} applies to #{action} and is not snippeted in v0"
            )
          end
          next
        end

        declaration.names.each do |name|
          next if skipped_names.include?(name)

          applicable << name
        end
      end
    end

    def callback_declarations(controller_class, action)
      body_statements(controller_class).filter_map do |node|
        next unless node.is_a?(Prism::CallNode)
        next unless node.receiver.nil?
        next unless (CALLBACK_DECLARATIONS + AROUND_DECLARATIONS + IGNORED_DECLARATIONS + %i[skip_before_action]).include?(node.name)

        callback_declaration(node, action)
      end
    end

    def callback_uncertainty_subject(declaration)
      declaration.names.empty? ? declaration.kind.to_s : declaration.names.join(", ")
    end

    def callback_declaration(node, action)
      names, options, dynamic = callback_arguments(node)

      CallbackDeclaration.new(
        kind: node.name,
        names: names,
        applies: !dynamic && applies_to_action?(options, action),
        dynamic: dynamic,
        block: !node.block.nil?,
        node: node
      )
    end

    def callback_arguments(node)
      arguments = node.arguments&.arguments || []
      keyword_hash = arguments.last if arguments.last.is_a?(Prism::KeywordHashNode)
      positional = keyword_hash ? arguments[0...-1] : arguments
      dynamic = false

      names = positional.map do |argument|
        literal_callback_name(argument).tap { |name| dynamic = true unless name }
      end.compact

      options = {}
      if keyword_hash
        keyword_hash.elements.each do |element|
          unless element.is_a?(Prism::AssocNode)
            dynamic = true
            next
          end

          key = literal_symbol(element.key)
          unless %w[only except].include?(key)
            dynamic = true
            next
          end

          literal_values = literal_filter_values(element.value)
          if literal_values
            options[key] = literal_values
          else
            dynamic = true
          end
        end
      end

      [names, options, dynamic]
    end

    def literal_callback_name(node)
      literal_symbol(node) || literal_string(node)
    end

    def literal_symbol(node)
      return unless node.is_a?(Prism::SymbolNode)

      node.unescaped
    end

    def literal_string(node)
      return unless node.is_a?(Prism::StringNode)

      node.unescaped
    end

    def literal_filter_values(node)
      single = literal_symbol(node) || literal_string(node)
      return [single] if single
      return unless node.is_a?(Prism::ArrayNode)

      values = node.elements.map { |element| literal_symbol(element) || literal_string(element) }
      return if values.any?(&:nil?)

      values
    end

    def applies_to_action?(options, action)
      applies = true
      applies &&= options.fetch("only").include?(action) if options.key?("only")
      applies &&= !options.fetch("except").include?(action) if options.key?("except")
      applies
    end

    def add_controller_evidence(packet, controller_relative_path, action_node, callbacks, methods)
      controller_entry = packet.add_file(controller_relative_path)
      callback_nodes = callbacks.filter_map do |name|
        callback_node = methods[name]
        unless callback_node
          packet.add_uncertainty(
            code: "unresolved_external_callbacks",
            subject: name,
            message: "callback #{name} applies but is not defined in the controller file"
          )
          next
        end

        [name, callback_node]
      end

      evidence_items, omitted = allocate_snippets(action_node, callback_nodes)
      evidence_items.each { |item| controller_entry.add_evidence(item) }
      omitted.each { |candidate| packet.omitted_candidates << candidate }
    end

    def allocate_snippets(action_node, callback_nodes)
      remaining = LIMITS.fetch(:max_snippet_lines_per_file)
      evidence_items = []
      omitted = []
      action_range = node_range(action_node)
      action_length = range_length(action_range)

      if action_length > remaining
        truncated_range = [action_range.first, action_range.first + remaining - 1]
        evidence_items << EvidenceItem.new(
          reason_code: "controller_action",
          subject: action_node.name.to_s,
          why: "controller action for requested anchor",
          snippet_ranges: [truncated_range],
          truncated: true
        )
        omitted << OmittedCandidate.new(
          category: "snippets",
          subject: action_node.name.to_s,
          reason: "action snippet exceeded max snippet lines per file",
          limit_key: :max_snippet_lines_per_file
        )
        callback_nodes.each do |name, _callback_node|
          omitted << OmittedCandidate.new(
            category: "snippets",
            subject: name,
            reason: "callback snippet exceeded remaining snippet lines per file",
            limit_key: :max_snippet_lines_per_file
          )
        end
        return [evidence_items, omitted]
      end

      evidence_items << EvidenceItem.new(
        reason_code: "controller_action",
        subject: action_node.name.to_s,
        why: "controller action for requested anchor",
        snippet_ranges: [action_range],
        truncated: false
      )
      remaining -= action_length

      callback_nodes.each do |name, callback_node|
        callback_range = node_range(callback_node)
        callback_length = range_length(callback_range)

        if callback_length <= remaining
          evidence_items << EvidenceItem.new(
            reason_code: "before_action_callback",
            subject: name,
            why: "callback #{name} applies to the requested action",
            snippet_ranges: [callback_range],
            truncated: false
          )
          remaining -= callback_length
        else
          omitted << OmittedCandidate.new(
            category: "snippets",
            subject: name,
            reason: "callback snippet exceeded remaining snippet lines per file",
            limit_key: :max_snippet_lines_per_file
          )
        end
      end

      [evidence_items, omitted]
    end

    def node_range(node)
      [node.location.start_line, node.location.end_line]
    end

    def range_length(range)
      range.last - range.first + 1
    end

    def add_view_candidates(packet, controller_path, action)
      view_paths = view_candidate_paths(controller_path, action)
      included = view_paths.first(LIMITS.fetch(:max_view_files))
      omitted = view_paths.drop(LIMITS.fetch(:max_view_files))

      included.each do |path|
        entry = packet.add_file(path)
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "view_candidate",
            subject: @anchor,
            why: "conventional view template for #{@anchor}",
            snippet_ranges: [],
            truncated: false
          )
        )
      end

      included.each do |path|
        packet.add_uncertainty(
          code: "view_inferred_by_convention",
          subject: path,
          message: "view template matched by action-template convention"
        )
      end

      omitted.each do |path|
        packet.omitted_candidates << OmittedCandidate.new(
          category: "view_files",
          subject: path,
          reason: "max view files limit reached",
          limit_key: :max_view_files
        )
      end
    end

    def view_candidate_paths(controller_path, action)
      action_token = action.sub(/[?!]\z/, "")
      glob = File.join(@app_root, "app", "views", controller_path, "#{action_token}.*")

      Dir.glob(glob).map do |absolute_path|
        next unless File.file?(absolute_path)
        next if File.basename(absolute_path).start_with?("_")

        relative_path(absolute_path)
      end.compact.sort
    end

    def add_constant_evidence(packet, action_node, callbacks, methods, controller_name)
      method_nodes = constant_scan_method_nodes(action_node, callbacks, methods)
      lexical_namespace = controller_name.split("::")[0...-1]
      resolved_by_path = {}
      ordered_resolutions = []

      method_nodes.each do |method_node|
        collect_constants(method_node.body).each do |reference|
          resolution = @constant_resolver.resolve(reference, lexical_namespace: lexical_namespace)
          next unless resolution
          next if resolved_by_path.key?(resolution.path)

          resolved_by_path[resolution.path] = resolution
          ordered_resolutions << resolution
        end
      end

      included = ordered_resolutions.first(LIMITS.fetch(:max_constant_files))
      omitted = ordered_resolutions.drop(LIMITS.fetch(:max_constant_files))

      included.each do |resolution|
        entry = packet.add_file(resolution.path)
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "referenced_constant",
            subject: resolution.constant_name,
            why: "constant #{resolution.constant_name} was referenced by the action, an applicable callback, or a same-file method transitively called from the action",
            snippet_ranges: [],
            truncated: false
          )
        )
        packet.convention_constant_matches << resolution
      end

      omitted.each do |resolution|
        packet.omitted_candidates << OmittedCandidate.new(
          category: "constant_files",
          subject: resolution.constant_name,
          reason: "max constant files limit reached",
          limit_key: :max_constant_files
        )
      end
    end

    def constant_scan_method_nodes(action_node, callbacks, methods)
      [action_node] +
        callbacks.filter_map { |name| methods[name] } +
        transitive_action_callee_nodes(action_node, methods)
    end

    def transitive_action_callee_nodes(action_node, methods)
      visited = { action_node.name.to_s => true }
      queued = {}
      queue = []
      callee_nodes = []

      enqueue_callee_names(collect_intra_file_call_names(action_node.body, methods), queue, queued, visited)

      until queue.empty?
        method_name = queue.shift
        queued.delete(method_name)
        next if visited[method_name]

        visited[method_name] = true
        method_node = methods[method_name]
        next unless method_node

        callee_nodes << method_node
        enqueue_callee_names(collect_intra_file_call_names(method_node.body, methods), queue, queued, visited)
      end

      callee_nodes
    end

    def enqueue_callee_names(names, queue, queued, visited)
      names.each do |name|
        next if visited[name] || queued[name]

        queue << name
        queued[name] = true
      end
    end

    def collect_intra_file_call_names(node, methods)
      method_names = methods.keys.each_with_object({}) { |name, memo| memo[name] = true }

      collect_call_nodes(node)
        .sort_by { |call_node| [call_node.location.start_offset, call_node.location.end_offset] }
        .filter_map do |call_node|
          method_name = call_node.name.to_s
          next if DYNAMIC_DISPATCH_CALLS.include?(method_name)
          next unless method_names[method_name]
          next unless intra_file_call_receiver?(call_node.receiver)

          method_name
        end
    end

    def collect_call_nodes(node)
      return [] unless node

      call_nodes = []
      call_nodes << node if node.is_a?(Prism::CallNode)
      child_nodes(node).each { |child| call_nodes.concat(collect_call_nodes(child)) }
      call_nodes
    end

    def intra_file_call_receiver?(receiver)
      receiver.nil? || receiver.is_a?(Prism::SelfNode)
    end

    def collect_constants(node, inside_constant_path = false)
      return [] unless node

      if node.is_a?(Prism::ConstantPathNode) && !inside_constant_path
        return [ConstantReference.new(
          name: constant_name(node),
          root: root_constant_path_node?(node),
          line: node.location.start_line
        )]
      end

      if node.is_a?(Prism::ConstantReadNode) && !inside_constant_path
        return [ConstantReference.new(name: node.name.to_s, root: false, line: node.location.start_line)]
      end

      child_nodes(node).flat_map do |child|
        collect_constants(child, inside_constant_path || node.is_a?(Prism::ConstantPathNode))
      end
    end

    def add_test_candidates(packet, controller_path, action)
      framework = detected_test_framework
      packet.test_framework = framework.to_s
      candidates = framework == :rspec ? rspec_test_candidates(controller_path, action) : minitest_test_candidates(controller_path, action)

      packet.no_test_candidates = candidates.empty?
      max_test_files = LIMITS.fetch(:max_test_files)
      remaining_file_slots = [LIMITS.fetch(:max_total_files) - packet.files.length, 0].max
      included_count = [max_test_files, remaining_file_slots].min
      included = candidates.first(included_count)

      included.each do |candidate|
        packet.tests << candidate
        entry = packet.add_file(candidate.path)
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: candidate.reason_code,
            subject: candidate.path,
            why: candidate.why,
            snippet_ranges: [],
            truncated: false
          )
        )

        if path_inferred_test_rule?(candidate.rule)
          packet.add_uncertainty(
            code: "test_inferred_by_path",
            subject: candidate.path,
            message: "test candidate was inferred by path"
          )
        end
      end

      candidates.each_with_index.drop(included_count).each do |candidate, index|
        limit_key = index < max_test_files ? :max_total_files : :max_test_files
        packet.omitted_candidates << OmittedCandidate.new(
          category: "test_files",
          subject: candidate.path,
          reason: index < max_test_files ? "max total files limit reached" : "max test files limit reached",
          limit_key: limit_key
        )
      end
    end

    def minitest_test_candidates(controller_path, action)
      candidates = []
      controller_test_path = File.join("test", "controllers", "#{controller_path}_controller_test.rb").tr(File::SEPARATOR, "/")
      if File.file?(File.join(@app_root, controller_test_path))
        candidates << test_candidate(
          path: controller_test_path,
          command: "bin/rails test #{controller_test_path}",
          reason_code: "minitest_candidate",
          rule: "conventional_controller_test",
          why: "matched conventional controller test path"
        )
      end

      path_token_matches("test/integration", "*_test.rb", controller_path, action).each do |path|
        candidates << test_candidate(
          path: path,
          command: "bin/rails test #{path}",
          reason_code: "minitest_candidate",
          rule: "integration_path_match",
          why: "matched integration test path tokens"
        )
      end

      candidates
    end

    def rspec_test_candidates(controller_path, action)
      candidates = []
      controller_spec_path = File.join("spec", "controllers", "#{controller_path}_controller_spec.rb").tr(File::SEPARATOR, "/")
      if File.file?(File.join(@app_root, controller_spec_path))
        candidates << test_candidate(
          path: controller_spec_path,
          command: "bundle exec rspec #{controller_spec_path}",
          reason_code: "rspec_candidate",
          rule: "conventional_controller_spec",
          why: "matched conventional controller spec path"
        )
      end

      path_token_matches("spec/requests", "*_spec.rb", controller_path, action).each do |path|
        candidates << test_candidate(
          path: path,
          command: "bundle exec rspec #{path}",
          reason_code: "rspec_candidate",
          rule: "request_spec_path_match",
          why: "matched request spec path tokens"
        )
      end

      candidates
    end

    def detected_test_framework
      rspec_app? ? :rspec : :minitest
    end

    def rspec_app?
      return false unless Dir.exist?(File.join(@app_root, "spec"))

      File.file?(File.join(@app_root, "spec", "rails_helper.rb")) || rspec_rails_dependency?
    end

    def rspec_rails_dependency?
      %w[Gemfile Gemfile.lock].any? do |name|
        path = File.join(@app_root, name)
        File.file?(path) && File.read(path).include?("rspec-rails")
      end
    end

    def path_inferred_test_rule?(rule)
      %w[integration_path_match request_spec_path_match].include?(rule)
    end

    def test_candidate(path:, command:, reason_code:, rule:, why:)
      TestCandidate.new(
        path: path,
        command: command,
        reason_code: reason_code,
        why: why,
        rule: rule
      )
    end

    def path_token_matches(relative_dir, glob, controller_path, action)
      absolute_dir = File.join(@app_root, relative_dir)
      return [] unless Dir.exist?(absolute_dir)

      controller_token = controller_path.split("/").last
      action_tokens = action.sub(/[?!]\z/, "").split("_").reject(&:empty?)

      Dir.glob(File.join(absolute_dir, glob)).map do |absolute_path|
        relative_path = relative_path(absolute_path)
        basename = File.basename(relative_path, ".rb")
        tokens = basename.split("_")

        next unless tokens.include?(controller_token)
        next unless contiguous_subsequence?(tokens, action_tokens)

        relative_path
      end.compact.sort
    end

    def contiguous_subsequence?(tokens, subsequence)
      return true if subsequence.empty?

      tokens.each_cons(subsequence.length).any? { |candidate| candidate == subsequence }
    end

    def repo_stamp
      commit, commit_status = Open3.capture2("git", "-C", @app_root, "rev-parse", "HEAD", err: File::NULL)
      return RepoStamp.new(commit: nil, dirty: false) unless commit_status.success?

      status_output, = Open3.capture2("git", "-C", @app_root, "status", "--porcelain", err: File::NULL)
      RepoStamp.new(commit: commit.strip, dirty: !status_output.empty?)
    rescue Errno::ENOENT
      RepoStamp.new(commit: nil, dirty: false)
    end

    def enforce_total_file_limit(packet)
      return if packet.files.length <= LIMITS.fetch(:max_total_files)

      packet.files.slice!(LIMITS.fetch(:max_total_files)..).each do |entry|
        packet.tests.reject! { |test| test.path == entry.path }
        packet.omitted_candidates << OmittedCandidate.new(
          category: omitted_category_for_entry(entry),
          subject: omitted_subject_for_entry(entry),
          reason: "max total files limit reached",
          limit_key: :max_total_files
        )
      end
    end

    def omitted_category_for_entry(entry)
      return "view_files" if entry.reason_codes.include?("view_candidate")
      return "test_files" if (entry.reason_codes & %w[minitest_candidate rspec_candidate]).any?
      return "constant_files" if entry.reason_codes.include?("referenced_constant")

      "files"
    end

    def omitted_subject_for_entry(entry)
      evidence = entry.evidence_items.first
      return entry.path unless evidence&.reason_code == "referenced_constant"

      evidence.subject
    end

    def constant_name(node)
      case node
      when Prism::ConstantReadNode
        node.name.to_s
      when Prism::ConstantPathNode
        parent = node.parent ? constant_name(node.parent) : nil
        [parent, node.name.to_s].compact.join("::")
      else
        ""
      end
    end

    def root_qualified_constant?(name)
      name.start_with?("::")
    end

    def root_constant_path_node?(node)
      return false unless node.is_a?(Prism::ConstantPathNode)

      current = node
      current = current.parent while current.parent.is_a?(Prism::ConstantPathNode)
      current.parent.nil? && current.delimiter_loc&.slice == "::"
    end

    def child_nodes(node)
      node.child_nodes.compact
    end

    def relative_path(path)
      File.expand_path(path).delete_prefix(@app_root + File::SEPARATOR).tr(File::SEPARATOR, "/")
    end
  end
end
