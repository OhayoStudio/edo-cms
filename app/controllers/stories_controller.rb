class StoriesController < ApplicationController
  # GET / (root)
  def index
    @top_story = Story.published.recent.with_slug.top.first
    @recent_stories = Story.published.recent.with_slug
    @recent_stories = (@recent_stories - [ @top_story ]).first(6) if @top_story.present?
    @videos = Video.joins(:story).where(stories: { is_published: true }).order("stories.published_at desc").limit(3)
    categories_with_articles = Category.joins(:articles).distinct
    @latest_stories_by_category = []

    categories_with_articles.each do |category|
      latest_story = Story.joins("INNER JOIN articles ON stories.storyable_id = articles.id")
                          .where(storyable_type: "Article",
                                is_published: true,
                                articles: { category_id: category.id })
                          .order(published_at: :desc)
                          .first

      @latest_stories_by_category << latest_story if latest_story
    end
  end

  # GET /stories/:id
  def show
    @story = Story.find(params[:id])
  end
end
