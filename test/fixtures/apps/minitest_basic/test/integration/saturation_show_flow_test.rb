class SaturationShowFlowTest < ActionDispatch::IntegrationTest
  def test_show_flow
    get saturation_path
    assert_response :success
  end
end
