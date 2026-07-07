# frozen_string_literal: true

# Tier 2 acceptance test — task 4 (behavior change at rooms/involvements#update).
# Hidden from the agent; copied to test/integration/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require_relative '../test_helper'

class Tier2Task4AcceptanceTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "invalid involvement redirects with alert and does not update membership" do
    membership = memberships(:david_watercooler)

    with_exceptions_rendered do
      assert_no_changes -> { membership.reload.involvement } do
        put room_involvement_url(rooms(:watercooler)), params: { involvement: "urgent" }
      end
    end

    assert_redirected_to room_involvement_url(rooms(:watercooler))
    assert flash[:alert].present?, "expected a flash alert for an invalid involvement"
  end

  test "valid involvement still updates membership" do
    assert_changes -> { memberships(:david_watercooler).reload.involvement }, from: "everything", to: "mentions" do
      put room_involvement_url(rooms(:watercooler)), params: { involvement: "mentions" }
    end

    assert_redirected_to room_involvement_url(rooms(:watercooler))
  end

  private
    def with_exceptions_rendered
      previous = Rails.application.env_config["action_dispatch.show_exceptions"]
      Rails.application.env_config["action_dispatch.show_exceptions"] = :all
      yield
    ensure
      Rails.application.env_config["action_dispatch.show_exceptions"] = previous
    end
end
