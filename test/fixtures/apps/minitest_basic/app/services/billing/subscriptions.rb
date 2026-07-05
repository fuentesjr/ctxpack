module Billing
  class Subscriptions
    def initialize(account)
      @account = account
    end

    def upgrade!(plan:)
      @account.update!(plan: plan)
    end
  end
end
