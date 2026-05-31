class StoriesController < ApplicationController
  # GET / (root)
  def index
    # preload(:storyable) avoids an N+1 when the story partials read
    # story.storyable for both rendering and the fragment cache key.
    @top_story = Story.published.recent.with_slug.top.preload(:storyable).first
    @recent_stories = Story.published.recent.with_slug.preload(:storyable).to_a
    @recent_stories = (@recent_stories - [ @top_story ]).first(6) if @top_story.present?
    @videos = Video.joins(:story).where(stories: { is_published: true }).order("stories.published_at desc").limit(3)

    # Most-recent published Article-story per category in a single query
    # (Postgres DISTINCT ON), replacing the previous query-per-category loop.
    @latest_stories_by_category =
      Story.published
           .joins("INNER JOIN articles ON stories.storyable_type = 'Article' AND stories.storyable_id = articles.id")
           .where.not("articles.category_id" => nil)
           .select("DISTINCT ON (articles.category_id) stories.*")
           .order(Arel.sql("articles.category_id, stories.published_at DESC"))
           .preload(:storyable)
           .to_a
           .sort_by { |s| s.published_at || Time.at(0) }
           .reverse
  end

  # GET /stories/:id
  def show
    @story = Story.find(params[:id])
  end
end
