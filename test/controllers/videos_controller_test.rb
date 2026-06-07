require "test_helper"

class VideosControllerTest < ActionDispatch::IntegrationTest
  fixtures :videos, :stories

  DUMMY_IMAGE = Rails.root.join("test", "fixtures", "files", "dummy_video_image.png").freeze

  def self.ensure_dummy_image
    return if File.exist?(DUMMY_IMAGE)
    FileUtils.mkdir_p(File.dirname(DUMMY_IMAGE))
    File.binwrite(DUMMY_IMAGE, "dummy image content for video controller test")
  end
  ensure_dummy_image

  setup do
    # video_intro_rails has a published story (see stories.yml), so it is
    # visible through the published-only #show scope. The index thumbnails
    # require an attached featured_image on every shown (published) video.
    @video = videos(:video_intro_rails)
    Video.joins(:story).where(stories: { is_published: true }).find_each { |v| attach_image(v) }
  end

  def attach_image(video)
    return if video.featured_image.attached?
    video.featured_image.attach(io: File.open(DUMMY_IMAGE), filename: "dummy_video_image.png", content_type: "image/png")
    video.save!
  end

  test "should get index and assign videos" do
    get videos_url
    assert_response :success
    assert_not_nil assigns(:videos), "@videos instance variable should be assigned"
  end

  test "should show a published video by id and assign it" do
    get video_url(id: @video.id)
    assert_response :success
    assert_equal @video, assigns(:video), "@video should be assigned correctly"
  end

  test "should show a published video by its FriendlyId slug" do
    get video_url(id: @video.slug)
    assert_response :success
    assert_equal @video, assigns(:video), "Should find the video by slug"
  end

  test "should redirect to root for a video without a published story" do
    # video_short_clip has no associated story, so it is not published. The
    # published-only scope raises RecordNotFound, which ApplicationController
    # rescues into a redirect to the root path.
    get video_url(id: videos(:video_short_clip).slug)
    assert_redirected_to root_path
  end
end
