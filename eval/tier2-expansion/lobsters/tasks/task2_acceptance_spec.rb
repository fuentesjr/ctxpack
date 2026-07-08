# typed: false

# Tier 2 acceptance test - task 2 (feature at users#standing).
# Hidden from the agent; copied to spec/requests/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require "rails_helper"

RSpec.describe "Tier2Task2UserStandingJsonAcceptance", type: :request do
  let(:user) { create(:user) }

  it "returns a JSON standing summary for the signed-in user" do
    flagged_comment = create(:comment, user: user)
    flagged_comment.update_columns(flags: 3)
    create(:comment, user: user)

    sign_in user
    get "/~#{user.username}/standing.json"

    expect(response).to be_successful
    summary = JSON.parse(response.body)
    expect(summary).to include(
      "username" => user.username,
      "n_comments" => 2,
      "n_flagged_comments" => 1,
      "n_flags" => 3
    )
  end
end
