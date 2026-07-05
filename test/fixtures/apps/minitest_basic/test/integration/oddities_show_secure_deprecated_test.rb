class OdditiesShowSecureDeprecatedTest < ActionDispatch::IntegrationTest
  def test_deprecated_secure_show
    get show_secure_deprecated_oddity_path(oddities(:pending))
    assert_response :success
  end
end
