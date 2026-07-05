class SyncBillingAccountJob
  def self.perform_later(account_id)
    new.perform(account_id)
  end

  def perform(account_id)
    account_id
  end
end
