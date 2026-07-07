# frozen_string_literal: true

# Tier 2 acceptance test — task 2 (feature at accounts#edit).
# Hidden from the agent; copied to test/integration/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require_relative '../test_helper'

class Tier2Task2AcceptanceTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "edit lists active bot users" do
    get edit_account_url

    assert_response :ok
    assert response.body.include?(users(:bender).name),
      "expected account settings to list the active bot #{users(:bender).name}"
  end
end
