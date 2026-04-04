class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit update destroy ]

  # GET /stories or /stories.json
  def index
    @top_story = Story.published.recent.with_slug.top.first
    @recent_stories = Story.published.recent.with_slug
    @recent_stories = (@recent_stories - [ @top_story ]).first(6) if @top_story.present?

    @videos = Video.all.order(created_at: :desc).limit(3)

    categories_with_articles = Category.joins(:articles).distinct
    @latest_stories_by_category = []

    categories_with_articles.each do |category|
      # Find the most recent story for each category
      latest_story = Story.joins("INNER JOIN articles ON stories.storyable_id = articles.id")
                          .where(storyable_type: "Article",
                                is_published: true,
                                articles: { category_id: category.id })
                          .order(published_at: :desc)
                          .first

      @latest_stories_by_category << latest_story if latest_story
    end
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
