require "test_helper"

# After a failed save the form can't refill its file field, so the picked file is
# stored and sent back by reference: the next save attaches it without picking it again.
class Admin::KeepUploadTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
  end

  def image = fixture_file_upload("dummy_video_image.png", "image/png")

  def kept_value(name)
    Nokogiri::HTML(response.body).at_css("input[type=hidden][name=\"#{name}\"]")&.[]("value")
  end

  test "article: the image picked before a failed save is attached on the next save" do
    article = articles(:article_published_tech)
    patch admin_article_path(article), params: { article: { content: "<p><br></p>", featured_image: image } }
    assert_response :unprocessable_entity
    kept = kept_value("article[featured_image]")
    assert kept.present?, "the form sends the stored file back"
    assert_includes response.body, "dummy_video_image.png"

    patch admin_article_path(article), params: { article: { content: "<p>Now with a body.</p>", featured_image: kept } }
    assert_response :redirect
    assert_equal "dummy_video_image.png", article.reload.featured_image.filename.to_s
  end


  test "a new article that fails keeps its image too" do
    post admin_articles_path, params: { article: { title: "Hi", content: "<p>Body</p>", featured_image: image } }
    assert_response :unprocessable_entity
    assert kept_value("article[featured_image]").present?
  end

  test "no hidden reference when nothing was picked" do
    patch admin_article_path(articles(:article_published_tech)), params: { article: { content: "<p><br></p>" } }
    assert_response :unprocessable_entity
    assert_nil kept_value("article[featured_image]")
  end
end
