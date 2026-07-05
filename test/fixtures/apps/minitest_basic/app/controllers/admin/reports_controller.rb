module Admin
  class ReportsController < ApplicationController
    before_action :prepare_report, only: [:show]

    def show
      Subscriptions.new(current_account).status
      render json: { status: Order::PENDING, missing: MissingThing.call, ok: true }
    end

    private

    def prepare_report
      ReportAudit.record("admin report shown")
    end
  end
end
