class ArticlesController < ApplicationController
  before_action :set_article, only: %i[ show edit update destroy ]

  # GET /articles or /articles.json
  def index
    @articles = Article.all
    @articles = @articles.published if params[:published].present?
    @articles = @articles.featured if params[:featured].present?
    @articles = @articles.where(category_id: params[:category_id]) if params[:category_id].present?
    @articles = @articles.where(author_id: params[:author_id]) if params[:author_id].present?
    @articles = @articles.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @articles = @articles.order(published_at: :desc)

    # @articles = @articles.page(params[:page]).per(10)
    @categories = Category.all
    @authors = Author.all

    # respond_to do |format|
    #   format.html
    #   format.json { render json: @articles }
    # end
  end

  # GET /articles/1 or /articles/1.json
  def show
  end

  # GET /articles/new
  def new
    @article = Article.new
  end

  # GET /articles/1/edit
  def edit
  end

  # POST /articles or /articles.json
  def create
    @article = Article.new(article_params)

    respond_to do |format|
      if @article.save
        # create storyable from @article
        Story.create(storyable: @article, slug: @article.slug, is_published: false)

        format.html { redirect_to @article, notice: "Article was successfully created." }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /articles/1 or /articles/1.json
  def update
    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to @article, notice: "Article was successfully updated." }
        format.json { render :show, status: :ok, location: @article }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /articles/1 or /articles/1.json
  def destroy
    @article.destroy!

    respond_to do |format|
      format.html { redirect_to articles_path, status: :see_other, notice: "Article was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_article
      @article = Article.friendly.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def article_params
      params.expect(article: [ :title, :subtitle, :content, :excerpt, :meta_description, :meta_keywords, :featured, :featured_image, :author_id, :category_id, :reading_time, :view_count, :status, :slug, :published_at ])
    end
end
