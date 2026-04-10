class Admin::VideosController < Admin::BaseController
  before_action :set_video, only: %i[edit update destroy publish unpublish ai_enhance_thumbnail promote_candidate_thumbnail destroy_candidate_thumbnail]

  def index
    @videos = Video.includes(:story)
                   .then { |q|
                     case params[:status]
                     when "published"   then q.joins(:story).where(stories: { is_published: true }).order("stories.published_at desc")
                     when "unpublished" then q.joins(:story).where(stories: { is_published: false }).order(created_at: :desc)
                     else                    q.order(created_at: :desc)
                     end
                   }
                   .page(params[:page]).per(10)
  end

  def metadata
    match = params[:url].to_s.match(YOUTUBE_ID_RE)
    return render json: {}, status: :bad_request unless match
    id = match[1]

    oembed = HTTParty.get("https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=#{id}&format=json")
    title  = oembed.success? ? oembed["title"] : nil

    description = nil
    if ENV["YOUTUBE_API_KEY"].present?
      api = HTTParty.get(
        "https://www.googleapis.com/youtube/v3/videos",
        query: { id: id, part: "snippet", key: ENV["YOUTUBE_API_KEY"] }
      )
      description = api.dig("items", 0, "snippet", "description") if api.success?
    end

    render json: { title: title, description: description }
  end

  def new
    @video = Video.new
  end

  def edit
  end

  def create
    @video = Video.new(video_params)
    if @video.save
      attach_youtube_thumbnail(@video) if @video.use_youtube_thumbnail == "1"
      Story.create(
        storyable:    @video,
        slug:         @video.slug,
        is_published: true,
        published_at: Time.current
      )
      redirect_to admin_videos_path, notice: "Video created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @video.assign_attributes(video_params)
    if @video.save
      attach_youtube_thumbnail(@video) if @video.use_youtube_thumbnail == "1"
      @video.story&.update(slug: @video.slug)
      redirect_to admin_videos_path, notice: "Video updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @video.destroy!
    redirect_to admin_videos_path, status: :see_other, notice: "Video deleted."
  end

  def publish
    Story.find_or_create_by(storyable: @video).update_columns(
      slug:         @video.slug,
      is_published: true,
      published_at: Time.current
    )
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("video-row-#{@video.id}") }
      format.html         { redirect_to admin_videos_path, notice: "Video published." }
    end
  end

  def unpublish
    @video.story&.update_column(:is_published, false)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("video-row-#{@video.id}") }
      format.html         { redirect_to admin_videos_path, notice: "Video unpublished." }
    end
  end

  # POST /admin/videos/:id/ai_enhance_thumbnail
  def ai_enhance_thumbnail
    return render json: { error: "No featured image attached" }, status: :unprocessable_entity unless @video.featured_image.attached?

    prompt     = params[:prompt].presence || default_enhance_prompt
    blob       = @video.featured_image.blob
    image_data = blob.download

    result = GeminiImageService.new.enhance(
      image_io:     StringIO.new(image_data),
      content_type: blob.content_type,
      prompt:       prompt
    )

    ext        = Rack::Mime::MIME_TYPES.invert[result[:content_type]] || ".jpg"
    filename   = "#{@video.slug}-enhanced-#{Time.current.to_i}#{ext}"
    new_blob   = ActiveStorage::Blob.create_and_upload!(
      io:           StringIO.new(result[:data]),
      filename:     filename,
      content_type: result[:content_type]
    )
    attachment = ActiveStorage::Attachment.create!(
      name:   "candidate_thumbnails",
      record: @video,
      blob:   new_blob
    )

    render json: {
      id:  attachment.id,
      url: url_for(new_blob.variant(resize_to_limit: [ 320, 180 ]))
    }, status: :ok
  rescue => e
    Rails.logger.error "[GeminiImage] #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /admin/videos/:id/promote_candidate_thumbnail
  def promote_candidate_thumbnail
    attachment = @video.candidate_thumbnails.find(params[:attachment_id])
    @video.featured_image.attach(attachment.blob)
    render json: { ok: true, url: url_for(@video.featured_image.variant(resize_to_limit: [ 200, 120 ])) }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # DELETE /admin/videos/:id/destroy_candidate_thumbnail
  def destroy_candidate_thumbnail
    attachment = @video.candidate_thumbnails.find(params[:attachment_id])
    attachment.purge
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def set_video
    @video = Video.friendly.find(params[:id])
  end

  def video_params
    params.require(:video).permit(:title, :description, :url, :featured_image, :use_youtube_thumbnail)
  end

  DEFAULT_ENHANCE_PROMPT = "Upscale this thumbnail to 4K resolution(3840×2160),
If there are back bands/borders at top and bottom or left/right, remove them and recenter the subject to the actual photo without these borders.
Keep 16:9 aspect ratio. Enhance sharpness, detail and contrast. Keep the subject and composition faithful to the original."
  # DEFAULT_ENHANCE_PROMPT = "Upscale this thumbnail to 4K resolution (3840×2160), 16:9 aspect ratio. Enhance sharpness, detail and contrast. Keep the subject and composition faithful to the original."

  YOUTUBE_ID_RE = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/

  def default_enhance_prompt = DEFAULT_ENHANCE_PROMPT

  def attach_youtube_thumbnail(video)
    match = video.url.to_s.match(YOUTUBE_ID_RE)
    return unless match
    id = match[1]

    # Try best quality first; maxresdefault returns a ~1KB placeholder when unavailable
    [ "maxresdefault", "sddefault", "hqdefault" ].each do |quality|
      response = HTTParty.get("https://img.youtube.com/vi/#{id}/#{quality}.jpg")
      next unless response.success?
      next if quality == "maxresdefault" && response.body.bytesize < 5_000
      video.featured_image.attach(
        io:           StringIO.new(response.body),
        filename:     "#{id}_#{quality}.jpg",
        content_type: "image/jpeg"
      )
      Rails.logger.info "YouTube thumbnail attached: #{quality} (#{response.body.bytesize} bytes)"
      break
    end
  end
end
