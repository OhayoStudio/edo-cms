class Admin::VideosController < Admin::BaseController
  before_action :set_video, only: %i[edit update destroy publish unpublish]

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

  private

  def set_video
    @video = Video.friendly.find(params[:id])
  end

  def video_params
    params.require(:video).permit(:title, :description, :url, :featured_image, :use_youtube_thumbnail)
  end

  YOUTUBE_ID_RE = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/

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
