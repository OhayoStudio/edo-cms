class Admin::ArticlesController < Admin::BaseController
  before_action :set_article, only: %i[edit update destroy publish unpublish patch_field preview]

  def index
    @categories = Category.not_deleted.order(:name)
    @articles = Article.includes(:author, :category)
                       .then { |q| params[:category_id].present? ? q.where(category_id: params[:category_id]) : q }
                       .then { |q| params[:status].present? ? q.where(status: params[:status]) : q }
                       .then { |q| params[:status] == "published" ? q.order(published_at: :desc) : q.order(priority: :desc, created_at: :desc) }
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
      Story.find_or_create_by(storyable: @article).update_columns(
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
      if @article.story
        @article.story.update(
          slug:         @article.slug,
          is_published: @article.published?,
          is_top:       @article.featured? || false
        )
      end
      generate_tags(@article)
      redirect_to admin_articles_path, notice: "Article updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!
    respond_to do |format|
      format.json { head :no_content }
      format.any  { redirect_to admin_articles_path, status: :see_other, notice: "Article deleted." }
    end
  end

  def publish
    @article.update_columns(status: Article.statuses[:published], published_at: Time.current)
    Story.find_or_create_by(storyable: @article).update_columns(
      slug:         @article.slug,
      is_published: true,
      published_at: @article.reload.published_at,
      is_top:       @article.featured? || false
    )
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("article-row-#{@article.id}") }
      format.html         { redirect_to admin_articles_path, notice: "Article published." }
    end
  end

  def unpublish
    @article.update_column(:status, Article.statuses[:draft])
    @article.story&.update_column(:is_published, false)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("article-row-#{@article.id}") }
      format.html         { redirect_to admin_articles_path, notice: "Article unpublished." }
    end
  end

  def preview
    render template: "articles/show", layout: "application"
  end

  # PATCH /admin/articles/:id/patch_field — lightweight single-field inline update
  def patch_field
    allowed = %w[category_id status featured priority]
    field   = params[:field].to_s
    return head :bad_request unless allowed.include?(field)

    @article.update_column(field, params[:value])
    @article.reload

    if field == "status" && @article.published?
      @article.update_column(:published_at, Time.current) if @article.published_at.nil?
      @article.reload
      Story.find_or_create_by(storyable: @article).update_columns(
        slug:         @article.slug,
        is_published: true,
        published_at: @article.published_at,
        is_top:       @article.featured? || false
      )
    elsif field == "status" && !@article.published?
      @article.story&.update_column(:is_published, false)
    end

    render json: { ok: true }
  rescue ArgumentError, ActiveRecord::StatementInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
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
    desired_names = article.meta_keywords.to_s.split(",").map(&:strip).reject(&:blank?).uniq

    desired_ids = desired_names.filter_map { |name| Tag.find_or_create_by(name: name).id }

    # Remove tags no longer in meta_keywords
    ArticlesTag.where(article_id: article.id)
               .where.not(tag_id: desired_ids)
               .delete_all

    # Add new ones
    desired_ids.each do |tag_id|
      ArticlesTag.find_or_create_by(article_id: article.id, tag_id: tag_id)
    end
  end
end
