module Ctxpack
  # Internal seed: evidence + kind. Expansion recipes live in Compiler.
  Seed = Struct.new(:kind, :evidence, :identity, keyword_init: true) do
    def self.anchor(evidence)
      normalized = evidence.to_s
      new(
        kind: "anchor",
        evidence: normalized,
        identity: identity_for_anchor(normalized)
      )
    end

    def self.test(evidence)
      normalized = evidence.to_s
      path, line = split_path_line(normalized)
      identity = File.basename(path, ".*")
      identity = "#{identity}_L#{line}" if line
      new(
        kind: "test",
        evidence: line ? "#{path}:#{line}" : path,
        identity: sanitize(identity)
      )
    end

    def self.files(paths)
      list = Array(paths).map(&:to_s)
      raise ArgumentError, "files seed requires at least one path" if list.empty?

      first = list.first
      new(
        kind: "files",
        evidence: list.join("\n"),
        identity: sanitize(File.basename(first, ".*"))
      )
    end

    def self.identity_for_anchor(anchor)
      sanitize(anchor.to_s)
    end

    def self.sanitize(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    end

    def self.split_path_line(value)
      if value =~ /\A(.+):(\d+)\z/
        [$1, $2.to_i]
      else
        [value, nil]
      end
    end

    def anchor?
      kind == "anchor"
    end

    def test?
      kind == "test"
    end

    def files?
      kind == "files"
    end

    def files_paths
      return [] unless files?

      evidence.to_s.split("\n").reject(&:empty?)
    end

    def test_path_and_line
      return [nil, nil] unless test?

      self.class.split_path_line(evidence)
    end

    def manifest_hash
      {
        "kind" => kind,
        "identity" => identity,
        "evidence" => evidence
      }
    end
  end
end
