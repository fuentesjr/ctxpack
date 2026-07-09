class SaturationControllerTest < ActionDispatch::IntegrationTest
  def test_show
    get saturation_path
    assert_response :success
  end
end
