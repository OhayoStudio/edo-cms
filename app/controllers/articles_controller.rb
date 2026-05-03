class ArticlesController < ApplicationController
  # GET /articles
  def index
    @articles = Article.published
    @articles = @articles.featured if params[:featured].present?
    @articles = @articles.where(category_id: params[:category_id]) if params[:category_id].present?
    @articles = @articles.where(author_id: params[:author_id]) if params[:author_id].present?
    if params[:search].present?
      search = "%#{params[:search]}%"
      @articles = @articles.where(
        "title ILIKE :q OR subtitle ILIKE :q OR excerpt ILIKE :q",
        q: search
      )
      tagged_articles = Article.published.joins(:tags).where("tags.name ILIKE :q", q: search)
      @articles = Article.where(id: @articles.select(:id)).or(Article.where(id: tagged_articles.select(:id)))
    end

    @articles = @articles.order(published_at: :desc).page(params[:page])
    @categories = Category.all
    @authors = Author.all
  end

  # GET /articles/:id
  def show
    @article = Article.published.friendly.find(params[:id])
  end
end
