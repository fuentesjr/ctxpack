# typed: false

# Tier 2 acceptance test - task 1 (feature at comments#disown).
# Hidden from the agent; copied to spec/requests/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require "rails_helper"

RSpec.describe "Tier2Task1CommentDisownCascadeAcceptance", type: :request do
  let(:author) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:inactive_user) { create(:user, :inactive) }
  let(:story) { create(:story, user: author) }

  def disownable_comment
    create(
      :comment,
      story: story,
      user: author,
      created_at: (Comment::DELETEABLE_DAYS + 1).days.ago
    )
  end

  it "disowns same-author direct replies when cascade is truthy" do
    comment = disownable_comment
    same_author_reply = create(:comment, story: story, user: author, parent_comment: comment)
    other_author_reply = create(:comment, story: story, user: other_user, parent_comment: comment)
    grandchild_reply = create(:comment, story: story, user: author, parent_comment: same_author_reply)

    sign_in author
    post "/comments/#{comment.short_id}/disown", params: {cascade: "1"}

    expect(response).to have_http_status(:found)
    expect(comment.reload.user).to eq(inactive_user)
    expect(same_author_reply.reload.user).to eq(inactive_user)
    expect(other_author_reply.reload.user).to eq(other_user)
    expect(grandchild_reply.reload.user).to eq(author)
  end

  it "leaves replies unchanged without cascade" do
    comment = disownable_comment
    same_author_reply = create(:comment, story: story, user: author, parent_comment: comment)

    sign_in author
    post "/comments/#{comment.short_id}/disown"

    expect(response).to have_http_status(:found)
    expect(comment.reload.user).to eq(inactive_user)
    expect(same_author_reply.reload.user).to eq(author)
  end
end
