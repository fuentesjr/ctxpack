require "digest"

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

    def self.error(frames)
      # frames: array of "path:line" relative to app root — never raw paste
      list = Array(frames).map(&:to_s).reject(&:empty?)
      raise ArgumentError, "error seed requires at least one application frame" if list.empty?

      digest = Digest::SHA256.hexdigest(list.join("|"))[0, 8]
      new(
        kind: "error",
        evidence: list.join("\n"),
        identity: "error_#{digest}"
      )
    end

    # Named `method` factory intentionally shadows Object#method on this class.
    def self.method(evidence)
      normalized = evidence.to_s
      constant, method_name = split_const_method(normalized)
      raise ArgumentError, "method seed requires Constant#method evidence (got #{evidence.inspect})" if constant.nil? || method_name.nil? || method_name.empty?

      new(
        kind: "method",
        evidence: "#{constant}##{method_name}",
        identity: sanitize("#{constant}##{method_name}")
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

    def self.split_const_method(value)
      return [nil, nil] unless value.include?("#")

      constant, method_name = value.split("#", 2)
      [constant, method_name]
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

    def error?
      kind == "error"
    end

    def method?
      kind == "method"
    end

    def files_paths
      return [] unless files?

      evidence.to_s.split("\n").reject(&:empty?)
    end

    def error_frames
      return [] unless error?

      evidence.to_s.split("\n").reject(&:empty?)
    end

    def test_path_and_line
      return [nil, nil] unless test?

      self.class.split_path_line(evidence)
    end

    def method_const_and_name
      return [nil, nil] unless method?

      self.class.split_const_method(evidence)
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
