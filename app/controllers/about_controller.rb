class AboutController < ApplicationController
  def index
    @about = About.instance
    @recent_articles = Article.published
                              .order(published_at: :desc)
                              .limit(3)
  end
end
