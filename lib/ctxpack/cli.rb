require "ctxpack"
require "fileutils"
require "optparse"
require "pathname"
require "open3"

module Ctxpack
  class CLI
    class FileOperationError < StandardError; end
    class TaskInputError < StandardError; end
    private_constant :FileOperationError
    private_constant :TaskInputError

    USAGE = <<~TEXT.freeze
      Usage:
        ctxpack <anchor> [options]
        ctxpack --from-test PATH[:LINE] [options]
        ctxpack --from-files PATH… [options]
        ctxpack --from-error - [options]
        ctxpack --from-method CONST#METHOD [options]
        ctxpack --from-diff RANGE|PATCH [options]
        ctxpack packet <anchor> [options]
    TEXT
    EXPLICIT_NAME_PATTERN = /\A[A-Za-z0-9_]+\z/
    ROUTE_HINT_ANCHOR_PATTERN = /\A(?<controller>[a-z][a-z0-9_]*(?:\/[a-z][a-z0-9_]*)*)#(?<action>_?[a-z][a-z0-9_]*)\z/
    ANCHOR_SEED_PATTERN = /\A[a-z][a-z0-9_]*(?:\/[a-z][a-z0-9_]*)*#_?[a-z][a-z0-9_]*[?!]?\z/

    def initialize(stdout: $stdout, stderr: $stderr, stdin: $stdin, cwd: Dir.pwd, clock: Time, history_provider: nil)
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @cwd = File.expand_path(cwd)
      @clock = clock
      @history_provider = history_provider
    end

    def run(argv)
      if version_request?(argv)
        @stdout.puts("ctxpack #{Ctxpack::VERSION}")
        return 0
      end

      if argv.empty? || help_request?(argv)
        @stdout.write(packet_parser({}).to_s)
        return 0
      end

      command, args = argv[0], argv[1..] || []
      if seed_flag?(command) || path_like_positional?(command) || command&.include?("#")
        args = argv
      elsif command != "packet"
        return 1 if print_syntactic_input_diagnostic(argv)
        return unknown_command_error(command)
      end
      return 1 if print_syntactic_input_diagnostic(args, route_only: true)

      options, remaining = parse_packet_args(args)
      @last_seed_token = Array(remaining).first
      if options.fetch(:help)
        @stdout.write(packet_parser({}).to_s)
        return 0
      end
      validate_options!(options)

      # CLI-17c: common Rails-shaped non-seeds fail before root discovery.
      if no_explicit_from_seed?(options) && remaining.is_a?(Array) && remaining.length == 1
        token = remaining.first
        unless token.match?(ANCHOR_SEED_PATTERN) || path_like_positional?(token)
          return 1 if print_syntactic_input_diagnostic([token])
        end
      end

      options[:task] = resolve_task(options)
      app_root = discover_app_root
      seeds = resolve_seeds!(options, remaining, app_root)
      primary = seeds.first
      @last_seed_token = primary.anchor? ? primary.evidence : primary.identity
      identity = seeds.map(&:identity).join("_")
      identity = identity[-80, 80] if identity.length > 80

      if (stdout_format = options.fetch(:stdout))
        packet = Ctxpack.compile(
          app_root: app_root,
          seeds: seeds,
          task: options.fetch(:task),
          history_provider: @history_provider
        )
        rendered = if stdout_format == :json
          Ctxpack.render_manifest(packet)
        else
          Ctxpack.render_markdown(packet)
        end
        @stdout.write(rendered)
        return 0
      end

      name = artifact_name(options.fetch(:name), options.fetch(:task), identity)
      markdown_path = markdown_path(app_root, options, name)
      manifest_path = sibling_manifest_path(markdown_path) if options.fetch(:manifest)
      if manifest_path&.casecmp?(markdown_path)
        raise ArgumentError, "manifest path would overwrite the Markdown artifact; choose an --out path that does not end in .json"
      end

      protect_outputs!([markdown_path, manifest_path].compact, options)

      packet = Ctxpack.compile(
        app_root: app_root,
        seeds: seeds,
        task: options.fetch(:task),
        history_provider: @history_provider
      )
      markdown = Ctxpack.render_markdown(packet)
      manifest = Ctxpack.render_manifest(packet) if manifest_path

      created_ctxpack_dir = create_parent_directories(app_root, [markdown_path, manifest_path].compact)
      write_artifact(markdown_path, markdown)
      write_artifact(manifest_path, manifest) if manifest_path

      print_gitignore_reminder(app_root) if created_ctxpack_dir && default_output?(options)
      @stdout.puts(display_path(markdown_path))
      @stdout.puts(display_path(manifest_path)) if manifest_path

      0
    rescue OptionParser::ParseError, ArgumentError => error
      @stderr.puts("ctxpack: #{error.message}")
      @stderr.puts(USAGE)
      1
    rescue Ctxpack::Error => error
      @stderr.puts("ctxpack: #{error.message}")
      @stderr.puts(route_discovery_hint(@last_seed_token))
      1
    rescue FileOperationError => error
      @stderr.puts("ctxpack: #{error.message}")
      1
    rescue TaskInputError => error
      @stderr.puts("ctxpack: #{error.message}")
      1
    end

    private

    def version_request?(argv)
      [["--version"], ["-v"]].include?(argv)
    end

    def help_request?(argv)
      argv.any? { |argument| ["--help", "-h"].include?(argument) }
    end

    def seed_flag?(token)
      token.is_a?(String) && token.start_with?("--from-")
    end

    def path_like_positional?(token)
      return false unless token.is_a?(String)

      token.end_with?(".rb", ".patch", ".diff") ||
        token.include?(".rb:") ||
        token.start_with?("test/", "spec/", "app/", "lib/", "config/")
    end

    def no_explicit_from_seed?(options)
      options[:from_anchor].nil? &&
        options[:from_test].nil? &&
        options[:from_files].empty? &&
        options[:from_error].nil? &&
        options[:from_method].nil? &&
        options[:from_diff].nil?
    end

    def parse_packet_args(args)
      options = {
        task: nil,
        task_explicit: false,
        task_file: nil,
        name: nil,
        dir: ".ctxpack",
        dir_explicit: false,
        out: nil,
        force: false,
        manifest: false,
        stdout: nil,
        help: false,
        from_anchor: nil,
        from_test: nil,
        from_files: [],
        from_error: nil,
        from_method: nil,
        from_diff: nil
      }

      parser = packet_parser(options)

      remaining = args.dup
      parser.parse!(remaining)
      return [options, nil] if options.fetch(:help)

      [options, remaining]
    end

    def packet_parser(options)
      OptionParser.new do |parser|
        parser.banner = <<~TEXT
          Generate a deterministic Rails context packet.

          #{USAGE.rstrip}

          Examples:
            ctxpack accounts#upgrade -t "Implement billing upgrade"
            ctxpack --from-test test/controllers/accounts_controller_test.rb:10 -t "Fix upgrade"
            ctxpack --from-files app/models/account.rb -t "Inspect account"
            ctxpack --from-method Billing::Subscriptions#upgrade! -t "Inspect upgrade!"
            ctxpack --from-diff main...HEAD -t "Review branch changes"
            ctxpack packet accounts#upgrade --task "Implement billing upgrade"
            cat issue.md | ctxpack accounts#upgrade --task-file - --stdout
            ctxpack accounts#upgrade --stdout=json | jq .

          Options:
        TEXT
        parser.on("-t TASK", "--task TASK", "Record the task in the packet and derived filename") do |task|
          options[:task] = task
          options[:task_explicit] = true
        end
        parser.on("--task-file PATH", "Read the task from PATH, or from standard input with -") { |path| options[:task_file] = path }
        parser.on("--from-anchor ANCHOR", "Compile from a controller#action anchor seed") { |v| options[:from_anchor] = v }
        parser.on("--from-test PATH", "Compile from a test/spec path seed (optional :line)") { |v| options[:from_test] = v }
        parser.on("--from-files PATHS", Array, "Compile from one or more file paths (comma-separated)") do |paths|
          options[:from_files].concat(Array(paths))
        end
        parser.on("--from-error PASTE", "Compile from a stack/log paste; use - to read stdin (PII-safe frames only)") do |v|
          options[:from_error] = v
        end
        parser.on("--from-method EVIDENCE", "Compile from a Namespace::Class#method seed (non-controller)") { |v| options[:from_method] = v }
        parser.on("--from-diff RANGE_OR_PATCH", "Compile from a git range or patch file path (explicit flag only)") { |v| options[:from_diff] = v }
        parser.on("--name NAME", "Set the timestamped artifact name") { |name| options[:name] = name }
        parser.on("-d DIR", "--dir DIR", "Set the timestamped output directory. Default: .ctxpack/") do |dir|
          options[:dir] = dir
          options[:dir_explicit] = true
        end
        parser.on("-o PATH", "--out PATH", "Write to an exact output path") { |path| options[:out] = path }
        parser.on("-f", "--force", "Overwrite existing output") { options[:force] = true }
        parser.on("--manifest", "Also write a sibling JSON manifest") { options[:manifest] = true }
        parser.on(
          "--stdout[=FORMAT]",
          %w[markdown json],
          "Write FORMAT to stdout without creating artifacts. Default: markdown"
        ) { |format| options[:stdout] = (format || "markdown").to_sym }
        parser.on("-h", "--help", "Show this help") { options[:help] = true }
        parser.separator("    -v, --version                    Show the ctxpack version (top-level only)")
        parser.separator("")
        parser.separator("Seeds (one or more --from-* flags; positional sugar is also a seed):")
        parser.separator("  controller#action, path, CONST#method, --from-anchor/--from-test/--from-files/--from-error/--from-method/--from-diff.")
        parser.separator("  --from-diff is flag-only (ranges/patches are not positional sugar; existing .patch paths are files seeds).")
        parser.separator("Paths and output:")
        parser.separator("  Run from any Rails app subdirectory; ctxpack discovers the application root.")
        parser.separator("  Task-file paths are relative to the invocation directory.")
        parser.separator("  Output destinations are relative to the Rails application root.")
        parser.separator("  Seed paths are relative to the Rails application root.")
        parser.separator("  Saved paths are printed relative to the invocation directory.")
        parser.separator("  Default output is timestamped Markdown under .ctxpack/.")
        parser.separator("  --manifest also saves sibling JSON; --stdout writes Markdown or JSON and saves nothing.")
        parser.separator("  --stdout conflicts with --dir, --out, --name, --force, and --manifest.")
        parser.separator("  --out conflicts with --dir and --name; --force is required to overwrite.")
      end
    end

    def validate_options!(options)
      if options.fetch(:task_explicit) && options.fetch(:task_file)
        raise ArgumentError, "--task cannot be combined with --task-file"
      end
      if options[:from_error] == "-" && options.fetch(:task_file) == "-"
        raise ArgumentError, "--from-error - cannot be combined with --task-file - (stdin is single-occupancy)"
      end
      if options.fetch(:stdout)
        conflicts = []
        conflicts << "--dir" if options.fetch(:dir_explicit)
        conflicts << "--out" if options.fetch(:out)
        conflicts << "--name" if options.fetch(:name)
        conflicts << "--force" if options.fetch(:force)
        conflicts << "--manifest" if options.fetch(:manifest)
        raise ArgumentError, "--stdout cannot be combined with #{conflicts.join(", ")}" unless conflicts.empty?
      end

      return unless options.fetch(:out)

      raise ArgumentError, "--out cannot be combined with --dir" if options.fetch(:dir_explicit)
      raise ArgumentError, "--out cannot be combined with --name" if options.fetch(:name)
    end

    def resolve_seeds!(options, remaining, app_root)
      remaining = Array(remaining)
      explicit = []
      explicit << :anchor if options[:from_anchor]
      explicit << :test if options[:from_test]
      explicit << :files if options[:from_files].any?
      explicit << :error if options[:from_error]
      explicit << :method if options[:from_method]
      explicit << :diff if options[:from_diff]

      seeds = []
      seeds << Seed.anchor(options[:from_anchor]) if options[:from_anchor]
      seeds << seed_from_test_evidence(options[:from_test], app_root) if options[:from_test]
      if options[:from_files].any?
        paths = options[:from_files].flat_map { |p| p.to_s.split(",") }.map(&:strip).reject(&:empty?)
        seeds << seed_from_files_evidence(paths, app_root)
      end
      seeds << seed_from_error_paste(options[:from_error], app_root) if options[:from_error]
      seeds << seed_from_method_evidence(options[:from_method]) if options[:from_method]
      seeds << seed_from_diff_evidence(options[:from_diff], app_root) if options[:from_diff]

      if remaining.any?
        raise ArgumentError, "too many positional arguments: #{remaining[1..].join(" ")}" if remaining.length > 1

        seeds << classify_positional_seed!(remaining.first, app_root)
      end

      raise ArgumentError, "missing seed; pass controller#action, a path, CONST#method, or a --from-* flag" if seeds.empty?

      seeds
    end

    def classify_positional_seed!(token, app_root)
      # SEED-10 dispatch
      if token.match?(ANCHOR_SEED_PATTERN)
        return Seed.anchor(token)
      end

      if token.include?("#")
        left = token.split("#", 2).first
        if left.match?(/Test\z|Spec\z/)
          raise ArgumentError, "TestClass#method sugar is not implemented yet; pass --from-test PATH instead"
        end
        if left.split("::").last&.end_with?("Controller")
          raise ArgumentError, "class-style controller references are suggest-only; rewrite to the underscore anchor (e.g. admin/accounts#suspend)"
        end
        if left.include?("::") || left.match?(/[A-Z]/)
          return seed_from_method_evidence(token)
        end
        # Malformed snake_case#… still goes through the anchor resolver so ANCH-1 errors surface.
        return Seed.anchor(token)
      end

      path_part, line = Seed.split_path_line(token)
      abs = File.join(app_root, path_part)
      if File.file?(abs)
        if path_part.start_with?("test/", "spec/")
          return seed_from_test_evidence(token, app_root)
        end
        if line
          raise ArgumentError, "line numbers on non-test paths are not accepted; strip :#{line} or use --from-files"
        end
        return seed_from_files_evidence([path_part], app_root)
      end

      raise ArgumentError, "unrecognized seed #{token.inspect}; expected controller#action or an existing app path"
    end

    def seed_from_test_evidence(evidence, app_root)
      path, = Seed.split_path_line(evidence)
      unless File.file?(File.join(app_root, path))
        raise ArgumentError, "test seed path does not exist: #{path}"
      end
      Seed.test(evidence)
    end

    def seed_from_files_evidence(paths, app_root)
      paths.each do |path|
        unless File.file?(File.join(app_root, path))
          raise ArgumentError, "files seed path does not exist: #{path}"
        end
      end
      Seed.files(paths, app_root: app_root)
    end

    def seed_from_error_paste(value, app_root)
      paste =
        if value == "-"
          begin
            @stdin.read
          rescue IOError => error
            raise TaskInputError, "could not read error paste from stdin: #{error.message}"
          end
        else
          value
        end
      frames = normalize_error_frames(paste, app_root)
      raise ArgumentError, "error seed found no application frames under app/, lib/, or config/" if frames.empty?

      Seed.error(frames)
    end

    def seed_from_method_evidence(evidence)
      Seed.method(evidence)
    rescue ArgumentError
      raise ArgumentError, "invalid method seed evidence #{evidence.inspect}; expected Namespace::Class#method"
    end

    def seed_from_diff_evidence(evidence, app_root)
      normalized = evidence.to_s
      raise ArgumentError, "diff seed requires a git range or patch path" if normalized.empty?

      if diff_patch_path?(normalized, app_root)
        abs = File.file?(File.join(app_root, normalized)) ? File.join(app_root, normalized) : File.expand_path(normalized, app_root)
        unless File.file?(abs)
          raise ArgumentError, "diff seed patch path does not exist: #{normalized}"
        end
        return Seed.diff(normalized, identity: Seed.sanitize(File.basename(normalized, ".*")))
      end

      identity = resolve_diff_range_identity(normalized, app_root)
      Seed.diff(normalized, identity: identity)
    end

    def diff_patch_path?(evidence, app_root)
      path = evidence.to_s
      return true if path.end_with?(".patch", ".diff")
      return true if File.file?(File.join(app_root, path))
      return true if !path.include?("..") && path.include?("/") && File.file?(File.expand_path(path, app_root))

      false
    end

    def resolve_diff_range_identity(range, app_root)
      resolved =
        if range.include?("...")
          left, right = range.split("...", 2)
          "#{short_git_ref(left, app_root)}...#{short_git_ref(right, app_root)}"
        elsif range.include?("..")
          left, right = range.split("..", 2)
          "#{short_git_ref(left, app_root)}..#{short_git_ref(right, app_root)}"
        else
          short_git_ref(range, app_root)
        end
      Seed.sanitize(resolved)
    rescue Ctxpack::Error
      # Identity resolution is best-effort at CLI parse; compiler fail-closes on the range.
      Seed.sanitize(range)
    end

    def short_git_ref(ref, app_root)
      out, err, status = Open3.capture3("git", "-C", app_root, "rev-parse", "--short", ref)
      return out.strip if status.success? && !out.strip.empty?

      raise Ctxpack::Error, "diff seed could not resolve range ref #{ref.inspect}: #{err.strip}"
    rescue Errno::ENOENT
      raise Ctxpack::Error, "diff seed requires git; git is not available on PATH"
    end

    def normalize_error_frames(paste, app_root)
      frames = []
      paste.to_s.each_line do |line|
        path = nil
        line_no = nil
        if (m = line.match(%r{(?:from\s+)?([^\s:]+?\.(?:rb|rake)):(\d+)}))
          path = m[1]
          line_no = m[2].to_i
        elsif (m = line.match(/"file"\s*:\s*"([^"]+)"\s*,\s*"line"\s*:\s*(\d+)/))
          path = m[1]
          line_no = m[2].to_i
        end
        next unless path

        rel = relativize_app_path(path, app_root)
        next unless rel
        next unless rel.match?(%r{\A(app|lib|config)/})
        next if rel.split("/").any? { |s| %w[vendor node_modules gems bundler].include?(s) }

        frames << "#{rel}:#{line_no}"
      end
      frames.uniq
    end

    def relativize_app_path(path, app_root)
      root = File.expand_path(app_root)
      abs = File.expand_path(path, root)
      return nil unless abs == root || abs.start_with?(root + File::SEPARATOR)
      return nil unless File.file?(abs)

      abs.delete_prefix(root + File::SEPARATOR).tr(File::SEPARATOR, "/")
    rescue ArgumentError
      nil
    end

    def resolve_task(options)
      path = options.fetch(:task_file)
      return options.fetch(:task) unless path

      content = if path == "-"
        begin
          @stdin.read
        rescue IOError => error
          raise TaskInputError, "could not read task from stdin: #{error.message}"
        end
      else
        File.binread(File.expand_path(path, @cwd))
      end
      content.sub(/(?:\r\n|\n)\z/, "")
    rescue SystemCallError => error
      raise TaskInputError, "could not read task file #{display_path(File.expand_path(path, @cwd))}: #{system_error_message(error)}"
    end

    def discover_app_root
      current = @cwd
      loop do
        return current if File.file?(File.join(current, "config", "application.rb"))

        parent = File.dirname(current)
        break if parent == current

        current = parent
      end

      raise ArgumentError, "searched upward from #{@cwd} for a Rails application root containing config/application.rb and found none"
    end

    def artifact_name(explicit_name, task, anchor)
      return explicit_artifact_name(explicit_name) if explicit_name

      task_name = sanitize_derived_name(task.to_s)
      anchor_name = sanitize_derived_name(anchor)
      limited_anchor_name = anchor_name.length > 80 ? anchor_name[-80, 80] : anchor_name
      return limited_anchor_name if task_name.empty?

      combined_name = "#{task_name}_#{anchor_name}"
      return combined_name if combined_name.length <= 80

      task_length = 80 - anchor_name.length - 1
      return limited_anchor_name if task_length <= 0

      task_prefix = task_name[0, task_length].sub(/_+\z/, "")
      "#{task_prefix}_#{anchor_name}"
    end

    def explicit_artifact_name(name)
      unless name.match?(EXPLICIT_NAME_PATTERN)
        raise ArgumentError, "--name must contain only letters, numbers, and underscores"
      end

      underscore(name)
    end

    def sanitize_derived_name(value)
      value.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    end

    def underscore(value)
      value = value.gsub(/::/, "/")
      value = value.gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
      value = value.gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
      value.downcase
    end

    def markdown_path(app_root, options, name)
      if options.fetch(:out)
        return resolve_output_path(app_root, options.fetch(:out))
      end

      filename = "#{current_utc.strftime("%Y%m%d%H%M%S")}_#{name}.md"
      File.join(resolve_output_path(app_root, options.fetch(:dir)), filename)
    end

    def sibling_manifest_path(markdown_path)
      extension = File.extname(markdown_path)
      basename = extension.empty? ? markdown_path : markdown_path.delete_suffix(extension)
      "#{basename}.json"
    end

    def resolve_output_path(app_root, path)
      return File.expand_path(path) if path.start_with?(File::SEPARATOR)

      File.expand_path(path, app_root)
    end

    def current_utc
      time = @clock.respond_to?(:call) ? @clock.call : @clock.now
      time.utc
    end

    def protect_outputs!(paths, options)
      non_file = paths.find { |path| File.exist?(path) && !File.file?(path) }
      raise FileOperationError, "output destination is not a file: #{display_path(non_file)}" if non_file

      return if options.fetch(:force)

      existing = paths.find { |path| File.exist?(path) }
      raise ArgumentError, "output already exists: #{display_path(existing)}; pass --force to overwrite" if existing
    end

    def create_parent_directories(app_root, paths)
      ctxpack_dir = File.join(app_root, ".ctxpack")
      ctxpack_dir_existed = Dir.exist?(ctxpack_dir)

      paths.map { |path| File.dirname(path) }.uniq.each do |dir|
        create_directory(dir)
      end

      !ctxpack_dir_existed && Dir.exist?(ctxpack_dir)
    end

    def create_directory(path)
      FileUtils.mkdir_p(path)
    rescue SystemCallError => error
      raise FileOperationError, "could not create directory #{display_path(path)}: #{system_error_message(error)}"
    end

    def write_artifact(path, content)
      File.binwrite(path, content)
    rescue SystemCallError => error
      raise FileOperationError, "could not write #{display_path(path)}: #{system_error_message(error)}"
    end

    def system_error_message(error)
      SystemCallError.new(error.class::Errno).message
    end

    def default_output?(options)
      !options.fetch(:dir_explicit) && !options.fetch(:out)
    end

    def print_gitignore_reminder(app_root)
      _stdout, _stderr, status = Open3.capture3(
        "git", "-C", app_root, "check-ignore", "--quiet", "--no-index", "--", ".ctxpack/"
      )
      return unless status.exitstatus == 1

      @stderr.puts("ctxpack: .ctxpack/ is not ignored; add `.ctxpack/` to .gitignore")
    rescue SystemCallError
      nil
    end

    def display_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(@cwd)).to_s
    end

    def usage_error(message)
      @stderr.puts("ctxpack: #{message}")
      @stderr.puts(USAGE)
      1
    end

    def unknown_command_error(command)
      @stderr.puts("ctxpack: unknown command #{command.inspect}")
      @stderr.puts("Did you mean `ctxpack packet`?") if command == "packets"
      @stderr.puts(USAGE)
      1
    end

    def print_syntactic_input_diagnostic(arguments, route_only: false)
      positional = arguments.reject { |argument| argument.start_with?("-") }
      value = positional.first.to_s

      if (route = route_string_parts(positional))
        hint = route.fetch(:path).split("/").reverse.find { |part| part.match?(/\A[a-z][a-z0-9_]*\z/) } || "ACTION"
        @stderr.puts("ctxpack: Rails route strings are not supported; pass a controller#action anchor")
        @stderr.puts("Try `bin/rails routes -g #{hint}` to find it.")
      elsif route_only
        return false
      elsif value.match?(/\A[a-z][a-z0-9_]*_[a-z0-9_]+\z/)
        @stderr.puts("ctxpack: #{value.inspect} looks like a Rails route helper, not a controller#action anchor")
        @stderr.puts("Try `bin/rails routes -g #{value}`, then pass the controller#action anchor shown by Rails.")
      elsif (match = /\A(?<controller>[A-Z][A-Za-z0-9]*(?:::[A-Z][A-Za-z0-9]*)*)Controller#(?<action>[a-z][a-z0-9_]*)\z/.match(value))
        anchor = "#{underscore(match[:controller])}##{match[:action]}"
        @stderr.puts("ctxpack: #{value.inspect} is a Ruby controller class reference; ctxpack expects a Rails route anchor such as #{anchor.inspect}")
        @stderr.puts("Confirm it with `bin/rails routes -g #{match[:action]}`.")
      elsif (match = /\A(?<controller>[a-z][a-z0-9_]*(?:\/[a-z][a-z0-9_]*)*)\/(?<action>[a-z][a-z0-9_]*)\z/.match(value))
        controller = match[:controller]
        action = match[:action]
        @stderr.puts("ctxpack: the final separator in #{value.inspect} should be #, not /")
        @stderr.puts("Try #{"#{controller}##{action}".inspect}.")
      else
        return false
      end

      true
    end

    def route_string_parts(arguments)
      joined = arguments.join(" ")
      match = /\A(?:GET|POST|PUT|PATCH|DELETE)\s+(?<path>\/[A-Za-z0-9_:.*()\/-]+)\z/.match(joined)
      { path: match[:path] } if match
    end

    def route_discovery_hint(anchor)
      match = ROUTE_HINT_ANCHOR_PATTERN.match(anchor.to_s)
      if match
        return "Use Rails-native route discovery, for example `bin/rails routes -g #{match[:action]}` or `bin/rails routes -c #{match[:controller]}`."
      end

      "Use Rails-native route discovery, for example `bin/rails routes -g ACTION` or `bin/rails routes -c CONTROLLER`."
    end
  end
end
