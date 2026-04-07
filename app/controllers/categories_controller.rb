class CategoriesController < ApplicationController
  # GET /categories
  def index
    @categories = Category.all
  end

  # GET /categories/:id
  def show
    @category = Category.friendly.find(params[:id])
    @articles = @category.articles.published.page(params[:page])
    @categories = Category.all
    render "articles/index"
  end
end
