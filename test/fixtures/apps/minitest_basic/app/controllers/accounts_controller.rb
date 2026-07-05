class AccountsController < ApplicationController
  before_action :authenticate_account, only: [:show]
  before_action :set_account, only: [:upgrade]
  before_action :load_dashboard, except: [:upgrade]
  prepend_before_action :require_active_account, only: [:upgrade]
  append_before_action :audit_upgrade, only: [:upgrade]
  around_action :with_billing_audit, only: [:upgrade]
  before_action(only: [:upgrade]) { |controller| controller.touch_request_context }

  def upgrade
    subscription = Billing::Subscriptions.new(@account)
    subscription.upgrade!(plan: params[:plan])
    SyncBillingAccountJob.perform_later(@account.id)
    redirect_to account_path(@account)
  end

  def bulk_update
    head :accepted
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def require_active_account
    redirect_to account_path(@account) unless @account.active?
  end

  def audit_upgrade
    Rails.logger.info("account upgraded")
  end

  def load_dashboard
    @dashboard = Dashboard.for(account: current_account)
  end
end
