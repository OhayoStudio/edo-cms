require "test_helper"

# A failed save re-renders the form with the just-uploaded file attached but not
# stored. Every admin form must show its errors then, not crash asking that file
# for a URL.
class Admin::FailedSaveWithUploadTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
  end

  def image = fixture_file_upload("dummy_video_image.png", "image/png")

  test "video" do
    patch admin_video_path(videos(:video_intro_rails)), params: { video: { title: "", featured_image: image } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Title can't be blank"
  end

  test "author" do
    patch admin_author_path(Author.first), params: { author: { first_name: "", avatar: image } }
    assert_response :unprocessable_entity
    assert_select "li", text: "First name can't be blank"
  end
end
