class AccountsControllerTest < ActionDispatch::IntegrationTest
  def test_upgrade_redirects
    post upgrade_account_path(accounts(:basic))
    assert_response :redirect
  end
end
