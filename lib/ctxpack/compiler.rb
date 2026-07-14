require "prism"
require "open3"
require "ctxpack/default_constant_resolver"
require "ctxpack/packet"
require "ctxpack/seed"

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

    def initialize(app_root:, task:, anchor: nil, seeds: nil, constant_resolver: nil)
      @app_root = File.expand_path(app_root)
      @task = task
      @seeds = normalize_seeds(anchor: anchor, seeds: seeds)
      @constant_resolver = constant_resolver || DefaultConstantResolver.new(app_root: @app_root)
    end

    def compile
      packets = @seeds.map { |seed| resolve_one_seed(seed) }
      return packets.first if packets.length == 1

      merge_packets(packets)
    end

    def resolve_one_seed(seed)
      case seed.kind
      when "anchor" then resolve_anchor_seed(seed)
      when "test" then resolve_test_seed(seed)
      when "files" then resolve_files_seed(seed)
      when "error" then resolve_error_seed(seed)
      when "method" then resolve_method_seed(seed)
      when "diff" then resolve_diff_seed(seed)
      else
        raise Error, "unsupported seed kind #{seed.kind.inspect}"
      end
    end

    def merge_packets(packets)
      # MERGE-2..5: union files in seed order, merge evidence, apply budgets once.
      first = packets.first
      merged = Packet.new(
        anchor: packets.map(&:anchor).compact.first,
        seeds: @seeds,
        task: @task,
        repo: first.repo,
        app_root: @app_root,
        entrypoint: packets.map(&:entrypoint).compact.first,
        version: 3
      )

      packets.each do |packet|
        packet.files.each do |entry|
          target = merged.add_file(entry.path)
          entry.evidence_items.each do |item|
            next if target.evidence_items.any? { |e| e.reason_code == item.reason_code && e.subject == item.subject }

            target.add_evidence(item)
          end
        end
        packet.tests.each do |test|
          next if merged.tests.any? { |t| t.path == test.path }

          merged.tests << test
        end
        packet.uncertainty.each do |note|
          merged.add_uncertainty(code: note.code, subject: note.subject, message: note.message)
        end
        packet.omitted_candidates.each do |om|
          next if merged.omitted_candidates.any? { |o| o.subject == om.subject && o.category == om.category }

          merged.omitted_candidates << om
        end
        packet.convention_constant_matches.each do |m|
          merged.convention_constant_matches << m unless merged.convention_constant_matches.include?(m)
        end
      end

      merged.no_test_candidates = merged.tests.empty?
      merged.test_framework = packets.map(&:test_framework).compact.first || detected_test_framework.to_s
      enforce_total_file_limit(merged)
      # Prefer not dropping primaries: if over limit, enforce_total_file_limit already truncated;
      # ensure any dropped primary is named (already via omitted when possible).
      merged
    end

    private

    def normalize_seeds(anchor:, seeds:)
      if seeds && anchor
        raise ArgumentError, "pass either anchor: or seeds:, not both"
      end

      list =
        if seeds
          Array(seeds).map { |s| s.is_a?(Seed) ? s : raise(ArgumentError, "seeds must be Ctxpack::Seed instances") }
        elsif anchor
          [Seed.anchor(anchor)]
        else
          raise ArgumentError, "compile requires an anchor: or seeds: argument"
        end

      raise ArgumentError, "compile requires at least one seed" if list.empty?

      list
    end

    def blank_packet(seed:, anchor: nil, entrypoint: nil)
      Packet.new(
        anchor: anchor,
        seeds: [seed],
        task: @task,
        repo: repo_stamp,
        app_root: @app_root,
        entrypoint: entrypoint,
        version: 3
      )
    end

    def resolve_test_seed(seed)
      path, line = seed.test_path_and_line
      abs = File.join(@app_root, path)
      unless File.file?(abs)
        raise Error, "test seed path does not exist: #{path}"
      end
      unless path.start_with?("test/", "spec/")
        raise Error, "test seed path must be under test/ or spec/: #{path}"
      end

      packet = blank_packet(seed: seed)
      entry = packet.add_file(path)
      entry.add_evidence(
        EvidenceItem.new(
          reason_code: "test_seed_primary",
          subject: line ? "#{path}:#{line}" : path,
          why: "user-named test seed",
          snippet_ranges: [],
          truncated: false
        )
      )

      surfaces = test_seed_surfaces(path)
      if surfaces.empty?
        packet.add_uncertainty(
          code: "test_seed_surface_uncertain",
          subject: path,
          message: "could not resolve a production surface for the test seed"
        )
      else
        surfaces.first(LIMITS.fetch(:max_constant_files)).each do |surface|
          se = packet.add_file(surface.fetch(:path))
          se.add_evidence(
            EvidenceItem.new(
              reason_code: surface.fetch(:reason_code),
              subject: surface.fetch(:subject),
              why: surface.fetch(:why),
              snippet_ranges: [],
              truncated: false
            )
          )
        end
      end

      # Suggest running the named test
      command =
        if path.start_with?("spec/")
          "bundle exec rspec #{path}"
        else
          "bin/rails test #{path}"
        end
      packet.tests << TestCandidate.new(
        path: path,
        command: command,
        reason_code: path.start_with?("spec/") ? "rspec_candidate" : "minitest_candidate",
        why: "user-named test seed",
        rule: "test_seed_primary"
      )
      packet.test_framework = path.start_with?("spec/") ? "rspec" : "minitest"
      enforce_total_file_limit(packet)
      packet
    end

    def test_seed_surfaces(rel)
      surfaces = []
      if (ctrl = controller_path_from_test(rel))
        surfaces << {
          path: ctrl,
          reason_code: "referenced_constant",
          subject: File.basename(ctrl, ".rb"),
          why: "production surface from test path convention"
        }
      end
      if surfaces.empty? && (token = request_token_controller(rel))
        surfaces << {
          path: token,
          reason_code: "referenced_constant",
          subject: File.basename(token, ".rb"),
          why: "production surface from request/integration path token"
        }
      end
      if surfaces.empty? && (const_path = constant_surface_from_test(rel))
        surfaces << {
          path: const_path,
          reason_code: "referenced_constant",
          subject: File.basename(const_path, ".rb"),
          why: "production surface from described_class/constant heuristic"
        }
      end
      surfaces
    end

    def controller_path_from_test(rel)
      case rel
      when %r{\Aspec/controllers/(.+)_controller_spec\.rb\z}
        candidate = "app/controllers/#{$1}_controller.rb"
      when %r{\Atest/controllers/(.+)_controller_test\.rb\z}
        candidate = "app/controllers/#{$1}_controller.rb"
      else
        return nil
      end
      File.file?(File.join(@app_root, candidate)) ? candidate : nil
    end

    def request_token_controller(rel)
      return nil unless rel.match?(%r{\A(?:spec/requests|test/integration)/})

      base = File.basename(rel).sub(/_(spec|test)\.rb\z/, "")
      tokens = base.split("_")
      candidates = []
      tokens.size.times do |i|
        slice = tokens[i..].join("_")
        next if slice.empty?

        Dir.glob(File.join(@app_root, "app/controllers/**/#{slice}_controller.rb")).each do |abs|
          candidates << abs.delete_prefix(@app_root + File::SEPARATOR).tr(File::SEPARATOR, "/")
        end
      end
      candidates.find { |c| File.file?(File.join(@app_root, c)) }
    end

    def constant_surface_from_test(rel)
      source = File.read(File.join(@app_root, rel), encoding: "UTF-8")
      const = source[/RSpec\.describe\s+([A-Z][A-Za-z0-9_:]*)/, 1]
      const ||= source[/class\s+([A-Z][A-Za-z0-9_:]*)\s*</, 1]
      return nil if const.nil? || const.end_with?("Test", "Spec")

      resolution = @constant_resolver.resolve(
        ConstantReference.new(name: const, root: true, line: 1),
        lexical_namespace: []
      )
      resolution&.path
    end

    def resolve_error_seed(seed)
      frames = seed.error_frames
      packet = blank_packet(seed: seed)
      frames.each do |frame|
        path, line_s = frame.split(":", 2)
        line = line_s.to_i
        next unless File.file?(File.join(@app_root, path))

        entry = packet.add_file(path)
        range = error_frame_range(path, line)
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "error_seed_frame",
            subject: frame,
            why: "application stack frame from error seed",
            snippet_ranges: [range],
            truncated: false
          )
        )
      end

      if packet.files.empty?
        raise Error, "error seed produced no application frames under app/, lib/, or config/"
      end

      packet.no_test_candidates = true
      packet.test_framework = detected_test_framework.to_s
      enforce_total_file_limit(packet)
      packet
    end

    def resolve_method_seed(seed)
      constant_name, method_name = seed.method_const_and_name
      if constant_name.nil? || method_name.nil? || method_name.empty?
        raise Error, "invalid method seed evidence #{seed.evidence.inspect}; expected Namespace::Class#method"
      end

      resolution = @constant_resolver.resolve_exact(constant_name)
      unless resolution
        raise Error,
              "method seed could not resolve constant #{constant_name}: " \
              "no conventional file under app/ for #{constant_name}"
      end

      relative_path = resolution.path
      absolute_path = File.join(@app_root, relative_path)
      source = File.read(absolute_path, encoding: "UTF-8")
      program = parse_ruby(source, relative_path)
      class_info = find_classes(program).find { |info| info.fetch(:name).delete_prefix("::") == constant_name.delete_prefix("::") }
      methods = class_info ? direct_methods(class_info.fetch(:node)) : {}
      method_node = methods[method_name]

      unless method_node
        raise Error,
              "method seed resolved #{relative_path} but found no instance def #{method_name} " \
              "whose enclosing constant is #{constant_name}"
      end

      packet = blank_packet(seed: seed)
      entry = packet.add_file(relative_path)
      method_range = node_range(method_node)
      remaining = LIMITS.fetch(:max_snippet_lines_per_file)
      method_length = range_length(method_range)
      if method_length > remaining
        truncated_range = [method_range.first, method_range.first + remaining - 1]
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "method_seed_primary",
            subject: method_name,
            why: "user-named method seed",
            snippet_ranges: [truncated_range],
            truncated: true
          )
        )
        packet.omitted_candidates << OmittedCandidate.new(
          category: "snippets",
          subject: method_name,
          reason: "method snippet exceeded max snippet lines per file",
          limit_key: :max_snippet_lines_per_file
        )
      else
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "method_seed_primary",
            subject: method_name,
            why: "user-named method seed",
            snippet_ranges: [method_range],
            truncated: false
          )
        )
      end

      # Same-file BFS expansion + constant scan; no test-candidate leg
      # (demoted by eval/seed-spikes/method/RESULTS.md — test-leg precision failed).
      add_method_seed_constant_evidence(packet, method_node, methods, constant_name, primary_path: relative_path)
      packet.no_test_candidates = true
      packet.test_framework = detected_test_framework.to_s
      enforce_total_file_limit(packet)
      packet
    end

    def add_method_seed_constant_evidence(packet, method_node, methods, constant_name, primary_path:)
      lexical_namespace = constant_name.delete_prefix("::").split("::")[0...-1]
      scan_nodes = [method_node] + transitive_action_callee_nodes(method_node, methods)
      resolved_by_path = { primary_path => true }
      ordered_resolutions = []

      scan_nodes.each do |node|
        collect_constants(node.body).each do |reference|
          resolution = @constant_resolver.resolve(reference, lexical_namespace: lexical_namespace)
          next unless resolution
          next if resolved_by_path.key?(resolution.path)

          resolved_by_path[resolution.path] = true
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
            why: "constant #{resolution.constant_name} was referenced by the method or a same-file method transitively called from it",
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

    def error_frame_range(path, line)
      abs = File.join(@app_root, path)
      total = File.foreach(abs).count
      window = snippet_context_window
      start_line = [1, line - window].max
      end_line = [total, line + window].min
      end_line = start_line if end_line < start_line
      [start_line, end_line]
    end

    def snippet_context_window
      15
    end

    def resolve_diff_seed(seed)
      evidence = seed.evidence.to_s
      raise Error, "diff seed requires a git range or patch path" if evidence.empty?

      entries, hunk_lines_by_path =
        if diff_patch_evidence?(evidence)
          enumerate_diff_from_patch(evidence)
        else
          enumerate_diff_from_range(evidence)
        end

      packet = blank_packet(seed: seed)
      max_files = LIMITS.fetch(:max_total_files)
      primary_paths = []

      entries.each do |entry|
        status = entry.fetch(:status)
        new_path = entry[:new]
        old_path = entry[:old]

        if status == "D" || (status.start_with?("R") && new_path.nil?)
          omitted_path = old_path || new_path
          if omitted_path
            packet.omitted_candidates << OmittedCandidate.new(
              category: "diff_files",
              subject: omitted_path,
              reason: "deleted or renamed-away path excluded from diff primaries",
              limit_key: :max_total_files
            )
          end
          next
        end

        if status.start_with?("R") && old_path && old_path != new_path
          packet.omitted_candidates << OmittedCandidate.new(
            category: "diff_files",
            subject: old_path,
            reason: "deleted or renamed-away path excluded from diff primaries",
            limit_key: :max_total_files
          )
        end

        path = new_path || old_path
        next if path.nil? || path.empty?
        next unless under_app_root?(path)
        unless File.file?(File.join(@app_root, path))
          packet.omitted_candidates << OmittedCandidate.new(
            category: "diff_files",
            subject: path,
            reason: "changed path does not exist in the working tree",
            limit_key: :max_total_files
          )
          next
        end

        if primary_paths.length >= max_files
          packet.omitted_candidates << OmittedCandidate.new(
            category: "diff_files",
            subject: path,
            reason: "max total files limit reached",
            limit_key: :max_total_files
          )
          next
        end

        primary_paths << path
        file_entry = packet.add_file(path)
        ranges = diff_snippet_ranges(path, hunk_lines_by_path.fetch(path, []))
        truncated = false
        if ranges.any?
          remaining = LIMITS.fetch(:max_snippet_lines_per_file)
          kept = []
          ranges.each do |range|
            length = range_length(range)
            if length > remaining
              if remaining.positive?
                kept << [range.first, range.first + remaining - 1]
              end
              truncated = true
              remaining = 0
              break
            else
              kept << range
              remaining -= length
            end
          end
          ranges = kept
          if truncated
            packet.omitted_candidates << OmittedCandidate.new(
              category: "snippets",
              subject: path,
              reason: "diff snippet exceeded max snippet lines per file",
              limit_key: :max_snippet_lines_per_file
            )
          end
        end

        file_entry.add_evidence(
          EvidenceItem.new(
            reason_code: "diff_seed_primary",
            subject: path,
            why: "changed file from diff seed",
            snippet_ranges: ranges,
            truncated: truncated
          )
        )
      end

      if entries.empty?
        raise Error, "diff seed found no changed files for #{evidence.inspect}"
      end

      add_diff_paired_tests(packet, primary_paths)
      packet.no_test_candidates = packet.tests.empty?
      packet.test_framework = detected_test_framework.to_s if packet.tests.empty?
      enforce_total_file_limit(packet)
      packet
    end

    def diff_patch_evidence?(evidence)
      path = evidence.to_s
      return true if path.end_with?(".patch", ".diff")
      return true if File.file?(File.join(@app_root, path))

      false
    end

    def under_app_root?(relative_path)
      abs = File.expand_path(relative_path, @app_root)
      abs == @app_root || abs.start_with?(@app_root + File::SEPARATOR)
    rescue ArgumentError
      false
    end

    def enumerate_diff_from_range(range)
      ensure_git_repo!
      out, err, status = Open3.capture3("git", "-C", @app_root, "diff", "--name-status", "-M", range)
      unless status.success?
        message = err.to_s.strip
        message = "unresolvable range" if message.empty?
        raise Error, "diff seed could not resolve range #{range.inspect}: #{message}"
      end

      entries = parse_name_status(out)
      hunk_lines = {}
      entries.each do |entry|
        path = entry[:new]
        next unless path && path.end_with?(".rb") && File.file?(File.join(@app_root, path))

        hunk_lines[path] = post_image_hunk_lines_from_range(range, path)
      end
      [entries, hunk_lines]
    rescue Errno::ENOENT
      raise Error, "diff seed requires git; git is not available on PATH"
    end

    def enumerate_diff_from_patch(evidence)
      abs =
        if File.file?(File.join(@app_root, evidence))
          File.join(@app_root, evidence)
        else
          File.expand_path(evidence, @app_root)
        end
      unless File.file?(abs)
        raise Error, "diff seed patch path does not exist: #{evidence}"
      end

      out, err, status = Open3.capture3("git", "apply", "--numstat", "--summary", abs)
      unless status.success?
        message = err.to_s.strip
        message = "unparseable patch" if message.empty?
        raise Error, "diff seed could not parse patch #{evidence.inspect}: #{message}"
      end

      entries = parse_apply_numstat(out)
      if entries.empty?
        raise Error, "diff seed could not parse patch #{evidence.inspect}: no changed files found"
      end

      hunk_lines = post_image_hunk_lines_from_patch(abs)
      [entries, hunk_lines]
    rescue Errno::ENOENT
      raise Error, "diff seed requires git; git is not available on PATH"
    end

    def ensure_git_repo!
      out, _err, status = Open3.capture3("git", "-C", @app_root, "rev-parse", "--is-inside-work-tree")
      return if status.success? && out.strip == "true"

      raise Error, "diff seed requires a git repository at the application root"
    rescue Errno::ENOENT
      raise Error, "diff seed requires git; git is not available on PATH"
    end

    def parse_name_status(output)
      output.to_s.each_line.filter_map do |line|
        cols = line.chomp.split("\t")
        next if cols.empty?

        status = cols[0]
        case status[0]
        when "R", "C"
          { status: status, old: cols[1], new: cols[2] }
        when "D"
          { status: status, old: cols[1], new: nil }
        else
          { status: status, old: nil, new: cols[1] }
        end
      end
    end

    def parse_apply_numstat(output)
      entries = []
      output.to_s.each_line do |line|
        line = line.chomp
        # numstat: "added\tdeleted\tpath" or "added\tdeleted\told => new"
        if (m = line.match(/\A(\d+|-)\t(\d+|-)\t(.+)\z/))
          path_field = m[3]
          if path_field.include?(" => ")
            old_path, new_path = path_field.split(" => ", 2)
            old_path = old_path.sub(/\A\{/, "").sub(/\}\z/, "")
            new_path = new_path.sub(/\A\{/, "").sub(/\}\z/, "")
            # strip brace rename form "dir/{old => new}"
            if path_field.include?("{")
              # fall through: prefer summary lines for renames
            end
            entries << { status: "R", old: old_path.strip, new: new_path.strip }
          else
            entries << { status: "M", old: nil, new: path_field }
          end
        elsif (m = line.match(/\A\s*rename (?:.* )?([\w.\/-]+) to ([\w.\/-]+)\z/))
          entries << { status: "R", old: m[1], new: m[2] }
        elsif (m = line.match(/\A\s*create mode \d+ (.+)\z/))
          entries << { status: "A", old: nil, new: m[1] }
        elsif (m = line.match(/\A\s*delete mode \d+ (.+)\z/))
          entries << { status: "D", old: m[1], new: nil }
        end
      end
      # Prefer unique by new||old path, first wins (numstat before summary)
      seen = {}
      entries.select do |e|
        key = e[:new] || e[:old]
        next false if key.nil? || seen[key]

        seen[key] = true
        true
      end
    end

    def post_image_hunk_lines_from_range(range, path)
      out, _err, status = Open3.capture3("git", "-C", @app_root, "diff", "-U0", range, "--", path)
      return [] unless status.success?

      parse_unified_diff_post_image_lines(out)
    end

    def post_image_hunk_lines_from_patch(abs_path)
      content = File.read(abs_path, encoding: "UTF-8")
      by_path = Hash.new { |h, k| h[k] = [] }
      current_path = nil
      content.each_line do |line|
        if (m = line.match(%r{\A\+\+\+ (?:b/)?(.+)\z}))
          path = m[1].strip
          current_path = path == "/dev/null" ? nil : path
          next
        end
        next unless current_path

        if (m = line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/))
          start = m[1].to_i
          count = (m[2] || "1").to_i
          next if start.zero? # pure deletion hunk

          count = 1 if count.zero?
          count.times { |i| by_path[current_path] << (start + i) }
        end
      end
      by_path.transform_values(&:uniq)
    end

    def parse_unified_diff_post_image_lines(diff_text)
      lines = []
      diff_text.to_s.each_line do |line|
        next unless (m = line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/))

        start = m[1].to_i
        count = (m[2] || "1").to_i
        next if start.zero?

        count = 1 if count.zero?
        count.times { |i| lines << (start + i) }
      end
      lines.uniq
    end

    def diff_snippet_ranges(path, changed_lines)
      return [] unless path.end_with?(".rb")
      return [] if changed_lines.empty?
      return [] unless File.file?(File.join(@app_root, path))

      def_ranges = prism_def_ranges(path)
      ranges = changed_lines.filter_map do |line|
        enclosing = innermost_def_range(def_ranges, line)
        if enclosing
          enclosing
        else
          error_frame_range(path, line)
        end
      end
      merge_line_ranges(ranges)
    end

    def prism_def_ranges(path)
      abs = File.join(@app_root, path)
      source = File.read(abs, encoding: "UTF-8")
      program = parse_ruby(source, path)
      ranges = []
      walk = lambda do |node|
        return if node.nil?

        if node.is_a?(Prism::DefNode)
          ranges << [node.location.start_line, node.location.end_line]
        end
        node.compact_child_nodes.each { |child| walk.call(child) }
      end
      walk.call(program)
      ranges
    end

    def innermost_def_range(def_ranges, line)
      covering = def_ranges.select { |start_line, end_line| line >= start_line && line <= end_line }
      return nil if covering.empty?

      covering.min_by { |start_line, end_line| end_line - start_line }
    end

    def merge_line_ranges(ranges)
      return [] if ranges.empty?

      sorted = ranges.map { |s, e| [s, e] }.sort_by(&:first)
      merged = [sorted.first.dup]
      sorted.drop(1).each do |start_line, end_line|
        last = merged.last
        if start_line <= last[1] + 1
          last[1] = [last[1], end_line].max
        else
          merged << [start_line, end_line]
        end
      end
      merged
    end

    def add_diff_paired_tests(packet, primary_paths)
      max_test_files = LIMITS.fetch(:max_test_files)
      candidates = []
      primary_paths.each do |path|
        next unless path.match?(%r{\Aapp/.+\.rb\z})

        mirror_test_candidates(path).each do |cand|
          next unless File.file?(File.join(@app_root, cand))
          next if candidates.any? { |c| c.path == cand }

          command = cand.start_with?("spec/") ? "bundle exec rspec #{cand}" : "bin/rails test #{cand}"
          candidates << test_candidate(
            path: cand,
            command: command,
            reason_code: "diff_seed_paired_test",
            rule: "diff_seed_mirror",
            why: "conventional mirror test for diff primary #{path}"
          )
        end
      end

      remaining_file_slots = [LIMITS.fetch(:max_total_files) - packet.files.length, 0].max
      included_count = [max_test_files, remaining_file_slots].min
      included = candidates.first(included_count)

      included.each do |candidate|
        packet.tests << candidate
        entry = packet.add_file(candidate.path)
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "diff_seed_paired_test",
            subject: candidate.path,
            why: candidate.why,
            snippet_ranges: [],
            truncated: false
          )
        )
      end

      candidates.drop(included_count).each_with_index do |candidate, index|
        limit_key = index < max_test_files ? :max_total_files : :max_test_files
        packet.omitted_candidates << OmittedCandidate.new(
          category: "test_files",
          subject: candidate.path,
          reason: limit_key == :max_total_files ? "max total files limit reached" : "max test files limit reached",
          limit_key: limit_key
        )
      end
    end

    def mirror_test_candidates(path)
      cands = []
      if (m = path.match(%r{\Aapp/controllers/(.+)_controller\.rb\z}))
        p = m[1]
        cands += [
          "test/controllers/#{p}_controller_test.rb",
          "spec/controllers/#{p}_controller_spec.rb",
          "spec/requests/#{p}_spec.rb",
          "spec/requests/#{p}_controller_spec.rb"
        ]
      end
      if (m = path.match(%r{\Aapp/([^/]+)/(.+)\.rb\z}))
        dir, p = m[1], m[2]
        cands += ["test/#{dir}/#{p}_test.rb", "spec/#{dir}/#{p}_spec.rb"]
      end
      if (m = path.match(%r{\Alib/(.+)\.rb\z}))
        cands += ["test/lib/#{m[1]}_test.rb", "spec/lib/#{m[1]}_spec.rb"]
      end
      cands.uniq
    end

    def resolve_files_seed(seed)
      paths = seed.files_paths
      paths.each do |path|
        unless File.file?(File.join(@app_root, path))
          raise Error, "files seed path does not exist: #{path}"
        end
      end

      packet = blank_packet(seed: seed)
      paths.each do |path|
        entry = packet.add_file(path)
        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "files_seed_primary",
            subject: path,
            why: "user-named files seed",
            snippet_ranges: [],
            truncated: false
          )
        )
      end

      neighbors = files_seed_neighbors(paths)
      neighbors.each do |neighbor|
        break if packet.files.size >= LIMITS.fetch(:max_total_files)

        entry = packet.add_file(neighbor.fetch(:path))
        next if entry.evidence_items.any?

        entry.add_evidence(
          EvidenceItem.new(
            reason_code: "files_seed_neighbor",
            subject: neighbor.fetch(:subject),
            why: neighbor.fetch(:why),
            snippet_ranges: [],
            truncated: false
          )
        )
      end

      # Collect test neighbors into Run section when they look like tests
      packet.files.each do |entry|
        path = entry.path
        next unless path.start_with?("test/", "spec/")
        next if packet.tests.any? { |t| t.path == path }

        command = path.start_with?("spec/") ? "bundle exec rspec #{path}" : "bin/rails test #{path}"
        packet.tests << TestCandidate.new(
          path: path,
          command: command,
          reason_code: path.start_with?("spec/") ? "rspec_candidate" : "minitest_candidate",
          why: "files seed neighbor or primary test",
          rule: "files_seed"
        )
      end
      packet.no_test_candidates = packet.tests.empty?
      packet.test_framework = detected_test_framework.to_s if packet.tests.empty?
      enforce_total_file_limit(packet)
      packet
    end

    def files_seed_neighbors(primaries)
      found = []
      primaries.each do |primary|
        if primary =~ %r{\Aapp/controllers/(.+)_controller\.rb\z}
          path = $1
          [
            "test/controllers/#{path}_controller_test.rb",
            "spec/controllers/#{path}_controller_spec.rb"
          ].each do |cand|
            next unless File.file?(File.join(@app_root, cand))

            found << { path: cand, subject: cand, why: "conventional controller test neighbor" }
          end
          view_dir = File.join(@app_root, "app/views", path)
          if Dir.exist?(view_dir)
            Dir.children(view_dir).sort.each do |name|
              abs = File.join(view_dir, name)
              next unless File.file?(abs)

              rel = "app/views/#{path}/#{name}"
              found << { path: rel, subject: rel, why: "same-prefix view neighbor" }
            end
          end
        else
          base = File.basename(primary, ".rb")
          %w[test spec].each do |dir|
            next unless Dir.exist?(File.join(@app_root, dir))

            Dir.glob(File.join(@app_root, dir, "**/*#{base}*")).sort.each do |abs|
              next unless File.file?(abs)

              rel = abs.delete_prefix(@app_root + File::SEPARATOR).tr(File::SEPARATOR, "/")
              found << { path: rel, subject: rel, why: "basename test neighbor" }
            end
          end
        end
      end
      found.uniq { |n| n[:path] }
    end

    def resolve_anchor_seed(seed)
      anchor = seed.evidence
      parsed_anchor = parse_anchor(anchor)
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

      packet = blank_packet(
        seed: seed,
        anchor: anchor,
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
            subject: packet.anchor,
            why: "conventional view template for #{packet.anchor}",
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
      return "test_files" if (entry.reason_codes & %w[minitest_candidate rspec_candidate diff_seed_paired_test]).any?
      return "constant_files" if entry.reason_codes.include?("referenced_constant")
      return "diff_files" if entry.reason_codes.include?("diff_seed_primary")

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
