require "test_helper"

class MappingProfilesControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get mapping_profiles_edit_url
    assert_response :success
  end

  test "should get update" do
    get mapping_profiles_update_url
    assert_response :success
  end
end
