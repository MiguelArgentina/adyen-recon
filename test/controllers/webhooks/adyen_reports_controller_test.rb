require "test_helper"

class Webhooks::AdyenReportsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get webhooks_adyen_reports_create_url
    assert_response :success
  end
end
