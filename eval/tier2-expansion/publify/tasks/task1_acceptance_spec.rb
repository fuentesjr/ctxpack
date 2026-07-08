# frozen_string_literal: true

# Tier 2 acceptance test - task 1 (feature at setup#index).
# Hidden from the agent; copied to spec/requests/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require "rails_helper"

RSpec.describe "Tier2Task1SetupNicknameAcceptance", type: :request do
  let(:strong_password) { "fhnehnhfiiuh" }

  before do
    ActionMailer::Base.deliveries.clear
    Blog.create
  end

  it "uses a submitted admin nickname during setup" do
    post "/setup", params: {
      blog: { blog_name: "Foo" },
      user: {
        email: "custom-admin@example.net",
        password: strong_password,
        nickname: "Custom Name"
      }
    }

    expect(User.find_by(login: "admin").nickname).to eq("Custom Name")
  end

  it "keeps the default admin nickname when none is submitted" do
    post "/setup", params: {
      blog: { blog_name: "Foo" },
      user: {
        email: "default-admin@example.net",
        password: strong_password
      }
    }

    expect(User.find_by(login: "admin").nickname).to eq("Publify Admin")
  end
end
