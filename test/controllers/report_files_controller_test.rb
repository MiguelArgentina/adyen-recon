require "test_helper"

class ReportFilesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get report_files_index_url
    assert_response :success
  end

  test "should get show" do
    get report_files_show_url
    assert_response :success
  end

  test "should get new" do
    get report_files_new_url
    assert_response :success
  end

  test "should get create" do
    get report_files_create_url
    assert_response :success
  end
end
