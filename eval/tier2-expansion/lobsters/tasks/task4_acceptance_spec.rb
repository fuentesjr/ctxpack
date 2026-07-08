# typed: false

# Tier 2 acceptance test - task 4 (behavior change at stories#update).
# Hidden from the agent; copied to spec/requests/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require "rails_helper"

RSpec.describe "Tier2Task4StoryUpdateDeletedAcceptance", type: :request do
  let(:user) { create(:user) }

  it "updates editable story attributes without resurrecting a deleted story" do
    story = create(
      :story,
      :deleted,
      user: user,
      title: "Original deleted title",
      created_at: 1.minute.ago
    )

    sign_in user
    patch "/stories/#{story.short_id}", params: {
      story: {
        title: "Edited while still deleted"
      }
    }

    expect(response).to have_http_status(:found)
    story.reload
    expect(story.title).to eq("Edited while still deleted")
    expect(story.is_deleted).to eq(true)
  end
end
