module Admin
  class AccountsController < ApplicationController
    def upgrade
      ::Billing::Subscriptions.new(current_account).upgrade!(plan: params[:plan])
    end
  end
end
