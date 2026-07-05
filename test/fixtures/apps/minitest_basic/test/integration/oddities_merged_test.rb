class OdditiesMergedTest < ActionDispatch::IntegrationTest
  def test_merged_check
    get merged_oddity_path(oddities(:pending))
    assert_response :success
  end
end
