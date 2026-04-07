class TagsController < ApplicationController
  # GET /tags
  def index
    @tags = Tag.all
  end

  # GET /tags/:id
  def show
    @tag = Tag.friendly.find(params[:id])
    @articles = @tag.articles.published.page(params[:page])
    @tags = Tag.all
    @categories = Category.all
    render "articles/index"
  end
end
