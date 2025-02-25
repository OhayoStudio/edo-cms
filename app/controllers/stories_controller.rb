class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit update destroy ]

  # GET /stories or /stories.json
  def index
    # @stories = Story.all
    @stories = Story.where(is_published: true)
                    .where.not(slug: nil)
                    .order(created_at: :desc)
    # .page(params[:page])

    @videos = Video.all

    # get 10 last videos from the youtube channel of JeromeSadou
    # youtube_channel_id = "UC9Z1XWw1kmnvOOFsj6Bzy2g"
    # youtube_api_key = Rails.application.credentials.dig(:youtube, :api_key)
    # youtube_url = "https://www.googleapis.com/youtube/v3/search?key=#{youtube_api_key}&channelId=#{youtube_channel_id}&part=snippet,id&order=date&maxResults=10"
    # youtube_response = HTTParty.get(youtube_url)
    # youtube_videos = youtube_response["items"]
    # @youtube_videos = youtube_videos

    # respond_to do |format|
    #   format.html
    #   format.json { render json: @stories }
    # end
  end

  # GET /stories/1 or /stories/1.json
  def show
  end

  # GET /stories/new
  def new
    @story = Story.new
  end

  # GET /stories/1/edit
  def edit
  end

  # POST /stories or /stories.json
  def create
    @story = Story.new(story_params)

    respond_to do |format|
      if @story.save
        format.html { redirect_to @story, notice: "Story was successfully created." }
        format.json { render :show, status: :created, location: @story }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @story.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /stories/1 or /stories/1.json
  def update
    respond_to do |format|
      if @story.update(story_params)
        format.html { redirect_to @story, notice: "Story was successfully updated." }
        format.json { render :show, status: :ok, location: @story }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @story.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stories/1 or /stories/1.json
  def destroy
    @story.destroy!

    respond_to do |format|
      format.html { redirect_to stories_path, status: :see_other, notice: "Story was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_story
      @story = Story.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def story_params
      params.expect(story: [ :slug, :is_published, :published_at, :storyable_id, :storyable_type ])
    end
end
