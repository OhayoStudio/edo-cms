class VideosController < ApplicationController
  # GET /videos
  def index
    all_videos      = Video.joins(:story).where(stories: { is_published: true }).order("stories.published_at desc")
    @videos         = all_videos.limit(3)
    @archive_videos = all_videos.offset(3).page(params[:archive_page]).per(5)
  end

  # GET /videos/:id
  def show
    @video = Video.joins(:story).where(stories: { is_published: true }).friendly.find(params[:id])
  end
end
