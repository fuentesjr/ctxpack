class BulkAccountsUpdateTest < ActionDispatch::IntegrationTest
  def test_bulk_accounts_update_order_is_not_a_bulk_update_match
    patch bulk_update_accounts_path
    assert_response :accepted
  end
end
