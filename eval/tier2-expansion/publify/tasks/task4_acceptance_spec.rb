# frozen_string_literal: true

# Tier 2 acceptance test - task 4 (behavior change at admin/users#destroy).
# Hidden from the agent; copied to spec/requests/ in the scoring
# environment only. See eval/tier2-expansion/PREREGISTRATION.md.

require "rails_helper"

RSpec.describe "Tier2Task4AdminUserDestroyAcceptance", type: :request do
  let!(:blog) { create(:blog) }
  let!(:current_admin) { create(:user, :as_admin) }
  let!(:other_admin) { create(:user, :as_admin) }
  let!(:third_admin) { create(:user, :as_admin) }

  before do
    third_admin
    sign_in current_admin
  end

  it "does not allow an admin to delete their own account" do
    delete "/admin/users/#{current_admin.id}"

    expect(response).to redirect_to(admin_users_path)
    expect(User.exists?(current_admin.id)).to eq(true)
  end

  it "still allows an admin to delete a different admin" do
    delete "/admin/users/#{other_admin.id}"

    expect(response).to redirect_to(admin_users_path)
    expect(User.exists?(other_admin.id)).to eq(false)
  end
end
