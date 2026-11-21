require "test_helper"

class Admin::ArticlesControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user = users(:one))
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "a failed save with a new featured image shows the errors instead of crashing" do
    sign_in
    article = articles(:article_published_tech)
    patch admin_article_path(article), params: { article: {
      content: "<p><br></p>",
      featured_image: fixture_file_upload("dummy_video_image.png", "image/png")
    } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Content can't be blank"
  end
end
