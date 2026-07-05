class AccountsUpgradeTest < ActionDispatch::IntegrationTest
  def test_upgrade_flow
    post upgrade_account_path(accounts(:basic))
    assert_response :redirect
  end
end
