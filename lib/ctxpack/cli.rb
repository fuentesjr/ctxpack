require "ctxpack"
require "fileutils"
require "optparse"

module Ctxpack
  class CLI
    USAGE = "usage: ctxpack packet <anchor> [--task TASK] [--name NAME] [--dir DIR] [--out PATH] [--force] [--manifest]".freeze
    EXPLICIT_NAME_PATTERN = /\A[A-Za-z0-9_]+\z/

    def initialize(stdout: $stdout, stderr: $stderr, cwd: Dir.pwd, clock: Time)
      @stdout = stdout
      @stderr = stderr
      @cwd = File.expand_path(cwd)
      @clock = clock
    end

    def run(argv)
      command, args = argv[0], argv[1..] || []
      return usage_error("unknown command #{command.inspect}") unless command == "packet"

      options, anchor = parse_packet_args(args)
      app_root = discover_app_root
      name = artifact_name(options.fetch(:name), options.fetch(:task), anchor)
      markdown_path = markdown_path(app_root, options, name)
      manifest_path = sibling_manifest_path(markdown_path) if options.fetch(:manifest)

      protect_outputs!([markdown_path, manifest_path].compact, options)

      packet = Ctxpack.compile(app_root: app_root, anchor: anchor, task: options.fetch(:task))
      markdown = Ctxpack.render_markdown(packet)
      manifest = Ctxpack.render_manifest(packet) if manifest_path

      created_ctxpack_dir = create_parent_directories(app_root, [markdown_path, manifest_path].compact)
      File.binwrite(markdown_path, markdown)
      File.binwrite(manifest_path, manifest) if manifest_path

      print_gitignore_reminder if created_ctxpack_dir
      @stdout.puts(display_path(markdown_path, app_root))
      @stdout.puts(display_path(manifest_path, app_root)) if manifest_path

      0
    rescue OptionParser::ParseError, ArgumentError => error
      @stderr.puts("ctxpack: #{error.message}")
      @stderr.puts(USAGE)
      1
    rescue Ctxpack::Error => error
      @stderr.puts("ctxpack: #{error.message}")
      @stderr.puts("Use Rails-native route discovery, for example `bin/rails routes -g ACTION` or `bin/rails routes -c CONTROLLER`.")
      1
    end

    private

    def parse_packet_args(args)
      options = {
        task: nil,
        name: nil,
        dir: ".ctxpack",
        out: nil,
        force: false,
        manifest: false
      }

      parser = OptionParser.new do |parser|
        parser.banner = USAGE
        parser.on("--task TASK") { |task| options[:task] = task }
        parser.on("--name NAME") { |name| options[:name] = name }
        parser.on("--dir DIR") { |dir| options[:dir] = dir }
        parser.on("--out PATH") { |path| options[:out] = path }
        parser.on("--force") { options[:force] = true }
        parser.on("--manifest") { options[:manifest] = true }
      end

      remaining = args.dup
      parser.parse!(remaining)
      raise ArgumentError, "missing anchor; expected controller#action" if remaining.empty?
      raise ArgumentError, "too many arguments: #{remaining[1..].join(" ")}" if remaining.length > 1

      [options, remaining.first]
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

      parts = []
      task_name = sanitize_derived_name(task.to_s)
      parts << task_name unless task_name.empty?
      parts << sanitize_derived_name(anchor)
      parts.join("_")[0, 80]
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
      return if options.fetch(:out) || options.fetch(:force)

      existing = paths.find { |path| File.exist?(path) }
      raise ArgumentError, "output already exists: #{existing}; pass --force to overwrite or --out to choose a path" if existing
    end

    def create_parent_directories(app_root, paths)
      ctxpack_dir = File.join(app_root, ".ctxpack")
      ctxpack_dir_existed = Dir.exist?(ctxpack_dir)

      paths.map { |path| File.dirname(path) }.uniq.each do |dir|
        FileUtils.mkdir_p(dir)
      end

      !ctxpack_dir_existed && Dir.exist?(ctxpack_dir)
    end

    def print_gitignore_reminder
      @stdout.puts("Reminder: add .ctxpack/ to .gitignore if you do not want local packets committed.")
    end

    def display_path(path, app_root)
      expanded_path = File.expand_path(path)
      expanded_root = File.expand_path(app_root)
      root_prefix = "#{expanded_root}#{File::SEPARATOR}"

      if expanded_path.start_with?(root_prefix)
        expanded_path.delete_prefix(root_prefix)
      else
        expanded_path
      end
    end

    def usage_error(message)
      @stderr.puts("ctxpack: #{message}")
      @stderr.puts(USAGE)
      1
    end
  end
end
