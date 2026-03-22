class Admin::VideosController < Admin::BaseController
  before_action :set_video, only: %i[edit update destroy publish unpublish]

  def index
    @videos = Video.order(created_at: :desc).page(params[:page]).per(10)
  end

  def new
    @video = Video.new
  end

  def edit
  end

  def create
    @video = Video.new(video_params)
    if @video.save
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
    if @video.update(video_params)
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
    Story.find_or_create_by(storyable: @video).update!(
      slug:         @video.slug,
      is_published: true,
      published_at: Time.current
    )
    redirect_to admin_videos_path, notice: "Video published."
  end

  def unpublish
    @video.story&.update!(is_published: false)
    redirect_to admin_videos_path, notice: "Video unpublished."
  end

  private

  def set_video
    @video = Video.friendly.find(params[:id])
  end

  def video_params
    params.require(:video).permit(:title, :description, :url, :featured_image)
  end
end
