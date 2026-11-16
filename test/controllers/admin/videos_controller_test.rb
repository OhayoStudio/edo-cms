require "test_helper"

class Admin::VideosControllerTest < ActionDispatch::IntegrationTest
  Resp = Struct.new(:body, :parsed, :ok) do
    def success? = ok
    def [](key) = parsed[key]
    def dig(*keys) = parsed.dig(*keys)
  end

  setup do
    user = User.create!(email_address: "vid@example.com", password: "password123",
                        password_confirmation: "password123")
    post session_path, params: { email_address: user.email_address, password: "password123" }
    @original_get = HTTParty.method(:get)
  end

  teardown do
    original = @original_get
    HTTParty.define_singleton_method(:get) { |*a, **kw, &b| original.call(*a, **kw, &b) }
  end

  # Minitest 6 has no stub; swap HTTParty.get by hand and restore in teardown.
  def stub_youtube
    HTTParty.define_singleton_method(:get) do |url, **|
      (Thread.current[:yt_calls] ||= []) << url
      if url.include?("oembed") then Resp.new("", { "title" => "Clip title" }, true)
      else Resp.new("", { "items" => [ { "snippet" => { "description" => "From the API" } } ] }, true)
      end
    end
    Thread.current[:yt_calls] = []
  end

  def with_api_key(value)
    previous = ENV["YOUTUBE_API_KEY"]
    ENV["YOUTUBE_API_KEY"] = value
    yield
  ensure
    ENV["YOUTUBE_API_KEY"] = previous
  end

  test "with an API key returns the oEmbed title and the Data API description" do
    stub_youtube
    with_api_key("test-key") { get metadata_admin_videos_path(url: "https://youtu.be/dQw4w9WgXcQ") }
    assert_response :success
    assert_equal({ "title" => "Clip title", "description" => "From the API" }, response.parsed_body)
  end

  test "without an API key only the title is returned and the Data API is not called" do
    stub_youtube
    with_api_key(nil) { get metadata_admin_videos_path(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") }
    assert_equal "Clip title", response.parsed_body["title"]
    assert_nil response.parsed_body["description"]
    assert_empty Thread.current[:yt_calls].grep(/googleapis/)
  end

  test "index renders a preview modal and one template per video" do
    video = videos(:video_intro_rails)
    video.update_column(:url, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    get admin_videos_path
    assert_response :success
    assert_select "[data-controller=video-preview] [data-video-preview-target=modal]"
    assert_select "button[data-action='video-preview#open'][data-video-id='#{video.id}']", 2
    assert_select "template#video-preview-#{video.id}"
    assert_match "youtube-nocookie.com/embed/dQw4w9WgXcQ", response.body
  end

  test "rejects a non-YouTube url" do
    get metadata_admin_videos_path(url: "https://example.com/x")
    assert_response :bad_request
  end
end
