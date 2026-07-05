class PrivateActionsController < ApplicationController
  private

  def upgrade
    head :ok
  end

  private def inline_upgrade
    head :accepted
  end
end
