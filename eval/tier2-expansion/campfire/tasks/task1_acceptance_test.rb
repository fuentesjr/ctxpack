# frozen_string_literal: true

# Tier 2 acceptance test — task 1 (feature at autocompletable/users#index).
# Hidden from the agent; copied to test/integration/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require_relative '../test_helper'

class Tier2Task1AcceptanceTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "except excludes selected users while preserving other matches" do
    get autocompletable_users_url(format: :json),
      params: { query: "j", except: [ users(:jason).id ] }

    assert_response :success
    names = response.parsed_body.map { |user| user["name"] }
    assert_not_includes names, "Jason"
    assert_includes names, "JZ"
  end

  test "except accepts a comma-separated list of user ids" do
    get autocompletable_users_url(format: :json),
      params: { query: "j", except: "#{users(:jason).id},#{users(:david).id}" }

    assert_response :success
    names = response.parsed_body.map { |user| user["name"] }
    assert_not_includes names, "Jason"
    assert_includes names, "JZ"
  end
end
