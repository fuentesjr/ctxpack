module Billing
  class UpgradeService
    def call
      DirectAlpha.prepare
      DirectBeta.prepare
      load_transitive
    end

    def load_transitive
      DirectGamma.prepare
      DirectDelta.prepare
      TransitiveEpsilon.prepare
    end

    def self.bulk_call
      DirectAlpha.prepare
    end
  end
end
