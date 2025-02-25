require "test_helper"

class AuthorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @author = authors(:one)
  end

  test "should get index" do
    get authors_url
    assert_response :success
  end

  test "should get new" do
    get new_author_url
    assert_response :success
  end

  test "should create author" do
    assert_difference("Author.count") do
      post authors_url, params: { author: { bio: @author.bio, deleted_at: @author.deleted_at, email: @author.email, first_name: @author.first_name, github_username: @author.github_username, last_name: @author.last_name, linkedin_url: @author.linkedin_url, role: @author.role, slug: @author.slug, status: @author.status, twitter_handle: @author.twitter_handle, website: @author.website } }
    end

    assert_redirected_to author_url(Author.last)
  end

  test "should show author" do
    get author_url(@author)
    assert_response :success
  end

  test "should get edit" do
    get edit_author_url(@author)
    assert_response :success
  end

  test "should update author" do
    patch author_url(@author), params: { author: { bio: @author.bio, deleted_at: @author.deleted_at, email: @author.email, first_name: @author.first_name, github_username: @author.github_username, last_name: @author.last_name, linkedin_url: @author.linkedin_url, role: @author.role, slug: @author.slug, status: @author.status, twitter_handle: @author.twitter_handle, website: @author.website } }
    assert_redirected_to author_url(@author)
  end

  test "should destroy author" do
    assert_difference("Author.count", -1) do
      delete author_url(@author)
    end

    assert_redirected_to authors_url
  end
end
