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

  test "should redirect to root for an unknown author id" do
    # Author.find raises RecordNotFound, which ApplicationController rescues
    # into a redirect to the root path.
    get author_url(id: -1)
    assert_redirected_to root_path
  end
end
