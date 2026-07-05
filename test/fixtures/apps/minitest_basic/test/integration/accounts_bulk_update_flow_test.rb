class AccountsBulkUpdateFlowTest < ActionDispatch::IntegrationTest
  def test_bulk_update_flow
    patch bulk_update_accounts_path
    assert_response :accepted
  end
end
