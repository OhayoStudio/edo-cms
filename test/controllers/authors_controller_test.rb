require "test_helper"

class AuthorsControllerTest < ActionDispatch::IntegrationTest
  fixtures :authors

  setup do
    @author = authors(:author_jane)
  end

  test "should show author by id and assign it" do
    get author_url(id: @author.id)
    assert_response :success
    assert_equal @author, assigns(:author), "@author should be assigned correctly"
  end

  test "an unknown author is not found" do
    get author_url(id: -1)
    assert_response :not_found
  end
end
