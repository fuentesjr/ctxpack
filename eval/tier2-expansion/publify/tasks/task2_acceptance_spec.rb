# frozen_string_literal: true

# Tier 2 acceptance test - task 2 (feature at tags#index).
# Hidden from the agent; copied to spec/requests/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require "rails_helper"

RSpec.describe "Tier2Task2TagsJsonAcceptance", type: :request do
  let!(:blog) { create(:blog) }

  it "returns each tag with its count of published contents" do
    tag = create(:tag, blog: blog, name: "tier2-topic")
    published_articles = create_list(:article, 2, blog: blog)
    draft_article = create(:unpublished_article, blog: blog)

    published_articles.each { |article| tag.contents << article }
    tag.contents << draft_article

    get "/tags.json"

    expect(response).to be_successful
    tag_json = JSON.parse(response.body).find { |entry| entry["name"] == tag.name }
    expect(tag_json).to include(
      "name" => tag.name,
      "articles_count" => published_articles.size
    )
  end
end
