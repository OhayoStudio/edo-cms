class ArticlesController < ApplicationController
  before_action :set_article, only: %i[ show edit update destroy ]

  # GET /articles or /articles.json
  def index
    @articles = Article.published
    @articles = @articles.published if params[:published].present?
    @articles = @articles.featured if params[:featured].present?
    @articles = @articles.where(category_id: params[:category_id]) if params[:category_id].present?
    @articles = @articles.where(author_id: params[:author_id]) if params[:author_id].present?
    if params[:search].present?
      search = "%#{params[:search]}%"
      @articles = @articles.where(
        "title ILIKE :q OR subtitle ILIKE :q OR excerpt ILIKE :q",
        q: search
      )
      # find articles by tag name and merge results, avoiding duplicates
      tagged_articles = Article.joins(:tags).where("tags.name ILIKE :q", q: search)
      @articles = Article.where(id: @articles.select(:id)).or(Article.where(id: tagged_articles.select(:id)))
    end

    @articles = @articles.order(published_at: :desc).page(params[:page])

    # @articles = @articles.page(params[:page]).per(10)
    @categories = Category.all
    @authors = Author.all
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
        Story.create(storyable: @article,
                     slug: @article.slug,
                     is_published: @article.published_at.present?,
                     published_at: @article.published_at,
                     is_top: @article.featured)


        generate_tags(@article)

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
        generate_tags(@article)
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
      @article = Article.published.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def article_params
      params.require(:article).permit(:title, :subtitle, :content, :excerpt, :meta_description, :meta_keywords, :featured, :featured_image, :author_id, :category_id, :reading_time, :view_count, :status, :slug, :published_at, photo_candidates: [])
    end

    def generate_tags(article)
      return if article.meta_keywords.blank?
      #  from comma separated string to array for meta_keywords
      meta_keywords = article.meta_keywords.split(",").map(&:strip)

      #  keep unique tags
      meta_keywords.uniq!

      #  for each tag in meta_keywords, create a tag if it doesn't exist
      meta_keywords.each do |name|
        tagg = Tag.find_or_create_by(name: name)
        ArticlesTag.find_or_create_by(article_id: article.id, tag_id: tagg.id)
      end
    end
end
