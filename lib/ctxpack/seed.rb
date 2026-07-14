module Ctxpack
  # Internal seed: evidence + kind. Expansion recipes live in Compiler.
  # Phase 1: only `anchor` is produced/consumed.
  Seed = Struct.new(:kind, :evidence, :identity, keyword_init: true) do
    def self.anchor(evidence)
      normalized = evidence.to_s
      new(
        kind: "anchor",
        evidence: normalized,
        identity: identity_for_anchor(normalized)
      )
    end

    def self.identity_for_anchor(anchor)
      anchor.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    end

    def anchor?
      kind == "anchor"
    end
  end
end
