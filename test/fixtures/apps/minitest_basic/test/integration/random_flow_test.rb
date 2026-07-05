class RandomFlowTest < ActionDispatch::IntegrationTest
  def test_mentions_content_mentions_upgrade_without_matching_path
    post content_mentions_upgrade_path
    assert_response :ok
  end
end
