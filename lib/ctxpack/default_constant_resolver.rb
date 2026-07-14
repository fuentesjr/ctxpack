module Ctxpack
  ConstantReference = Struct.new(:name, :root, :line, keyword_init: true)
  ConstantResolution = Struct.new(:original_name, :constant_name, :path, keyword_init: true)

  class DefaultConstantResolver
    EXCLUDED_APP_DIRS = %w[assets javascript views].freeze

    def initialize(app_root:)
      @app_root = File.expand_path(app_root)
    end

    def resolve(reference, lexical_namespace:)
      candidate_names(reference, lexical_namespace).each do |candidate_name|
        segments = candidate_name.split("::")

        segments.length.downto(1) do |length|
          trimmed_name = segments.first(length).join("::")
          path = conventional_path(trimmed_name)
          next unless path

          return ConstantResolution.new(
            original_name: reference.name,
            constant_name: trimmed_name,
            path: path
          )
        end
      end

      nil
    end

    # Exact constant → conventional path only (no segment trimming). Used by
    # the method seed for evidence-constant resolution (SEED method recipe).
    def resolve_exact(constant_name)
      name = constant_name.to_s.delete_prefix("::")
      path = conventional_path(name)
      return nil unless path

      ConstantResolution.new(
        original_name: name,
        constant_name: name,
        path: path
      )
    end

    private

    def candidate_names(reference, lexical_namespace)
      return [reference.name] if reference.root

      namespace_prefixes = lexical_namespace.length.downto(1).map do |length|
        lexical_namespace.first(length).join("::")
      end

      namespace_prefixes.map { |prefix| "#{prefix}::#{reference.name}" } + [reference.name]
    end

    def conventional_path(constant_name)
      relative_constant_path = underscore_constant(constant_name) + ".rb"

      app_subdirectories.each do |subdirectory|
        candidate = File.join(@app_root, "app", subdirectory, relative_constant_path)
        return relative_path(candidate) if File.file?(candidate)
      end

      nil
    end

    def app_subdirectories
      app_dir = File.join(@app_root, "app")
      return [] unless Dir.exist?(app_dir)

      Dir.children(app_dir)
         .select { |entry| File.directory?(File.join(app_dir, entry)) }
         .reject { |entry| EXCLUDED_APP_DIRS.include?(entry) }
         .sort
    end

    def underscore_constant(constant_name)
      constant_name
        .gsub("::", "/")
        .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr("-", "_")
        .downcase
    end

    def relative_path(path)
      path.delete_prefix(@app_root + File::SEPARATOR).tr(File::SEPARATOR, "/")
    end
  end
end
