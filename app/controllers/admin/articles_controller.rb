class Admin::ArticlesController < Admin::BaseController
  before_action :set_article, only: %i[edit update destroy publish unpublish]

  def index
    @articles = Article.includes(:author, :category)
                       .order(created_at: :desc)
                       .page(params[:page]).per(10)
  end

  def new
    @article = Article.new
  end

  def edit
  end

  def create
    @article = Article.new(article_params)
    if @article.save
      Story.find_or_create_by(storyable: @article).update!(
        slug:         @article.slug,
        is_published: @article.published?,
        published_at: @article.published_at,
        is_top:       @article.featured? || false
      )
      generate_tags(@article)
      redirect_to admin_articles_path, notice: "Article created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @article.update(article_params)
      @article.story&.update(
        slug:   @article.slug,
        is_top: @article.featured? || false
      )
      generate_tags(@article)
      redirect_to admin_articles_path, notice: "Article updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!
    redirect_to admin_articles_path, status: :see_other, notice: "Article deleted."
  end

  def publish
    @article.update!(status: :published, published_at: Time.current)
    Story.find_or_create_by(storyable: @article).update!(
      slug:         @article.slug,
      is_published: true,
      published_at: @article.published_at,
      is_top:       @article.featured? || false
    )
    redirect_to admin_articles_path, notice: "Article published."
  end

  def unpublish
    @article.update!(status: :draft)
    @article.story&.update!(is_published: false)
    redirect_to admin_articles_path, notice: "Article unpublished."
  end

  private

  def set_article
    @article = Article.friendly.find(params[:id])
  end

  def article_params
    params.require(:article).permit(
      :title, :subtitle, :content, :excerpt,
      :meta_description, :meta_keywords,
      :featured, :featured_image,
      :author_id, :category_id,
      :reading_time, :status, :slug, :published_at
    )
  end

  def generate_tags(article)
    return if article.meta_keywords.blank?
    meta_keywords = article.meta_keywords.split(",").map(&:strip).uniq
    meta_keywords.each do |name|
      tag = Tag.find_or_create_by(name: name)
      ArticlesTag.find_or_create_by(article_id: article.id, tag_id: tag.id)
    end
  end
end
