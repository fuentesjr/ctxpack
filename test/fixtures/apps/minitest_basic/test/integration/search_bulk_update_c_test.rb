class SearchBulkUpdateCTest < ActionDispatch::IntegrationTest
  def test_bulk_update
    patch search_bulk_update_path
    assert_response :accepted
  end
end
