class InstagramService
  include HTTParty

  GRAPH_BASE = "https://graph.facebook.com/v21.0"

  def initialize
    @access_token = ENV.fetch("INSTAGRAM_ACCESS_TOKEN", "")
    @user_id      = ENV.fetch("INSTAGRAM_USER_ID",       "")
  end

  # ── Reading ────────────────────────────────────────────────────────────────

  def get_liked_posts
    response = HTTParty.get(
      "https://graph.instagram.com/me/media",
      query: {
        fields: "id,caption,media_type,media_url,permalink,thumbnail_url,timestamp,username",
        access_token: @access_token
      }
    )
    raise "Error fetching posts: #{response.body}" unless response.success?
    JSON.parse(response.body)["data"]
  end

  # ── Publishing Stories ─────────────────────────────────────────────────────

  # Publishes a static image Story.
  # media_url must be a publicly accessible HTTPS URL (no localhost).
  # Returns the published media ID string.
  def publish_image_story(media_url:)
    creation_id = create_container(image_url: media_url)
    publish_container(creation_id)
  end

  # Publishes a video Story.
  # Polls for container readiness (Instagram processes video server-side).
  # Returns the published media ID string.
  def publish_video_story(media_url:)
    creation_id = create_container(video_url: media_url)
    wait_for_container(creation_id)
    publish_container(creation_id)
  end

  private

  def create_container(image_url: nil, video_url: nil)
    params = { media_type: "STORIES", access_token: @access_token }
    params[:image_url] = image_url if image_url
    params[:video_url] = video_url if video_url

    response = HTTParty.post("#{GRAPH_BASE}/#{@user_id}/media", query: params)
    body = JSON.parse(response.body)
    raise "Instagram container error: #{response.body}" unless response.success? && body["id"]
    body["id"]
  end

  def publish_container(creation_id)
    response = HTTParty.post(
      "#{GRAPH_BASE}/#{@user_id}/media_publish",
      query: { creation_id: creation_id, access_token: @access_token }
    )
    body = JSON.parse(response.body)
    raise "Instagram publish error: #{response.body}" unless response.success? && body["id"]
    body["id"]
  end

  # Polls container status until FINISHED (or ERROR / timeout).
  def wait_for_container(creation_id, timeout: 60)
    deadline = Time.current + timeout
    loop do
      response = HTTParty.get(
        "#{GRAPH_BASE}/#{creation_id}",
        query: { fields: "status_code", access_token: @access_token }
      )
      status = JSON.parse(response.body)["status_code"]
      return if status == "FINISHED"
      raise "Instagram video processing failed (status: #{status})" if %w[ERROR EXPIRED].include?(status)
      raise "Instagram video processing timed out after #{timeout}s" if Time.current > deadline
      sleep 3
    end
  end
end
