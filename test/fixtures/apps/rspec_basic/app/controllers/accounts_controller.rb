class AccountsController < ApplicationController
  def upgrade
    head :ok
  end

  def bulk_update
    head :accepted
  end
end
