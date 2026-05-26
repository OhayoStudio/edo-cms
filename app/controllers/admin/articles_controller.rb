class Admin::ArticlesController < Admin::BaseController
  before_action :set_article, only: %i[edit update destroy publish unpublish patch_field preview story_card story_video share_instagram]

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

  # GET /admin/articles/:id/story_card — download a 1080×1920 PNG story card
  def story_card
    image_data = InstagramStoryService.new(@article, **story_params).generate
    if image_data
      send_data image_data, type: "image/png",
                filename: "#{@article.slug}-story.png", disposition: "attachment"
    else
      redirect_to edit_admin_article_path(@article), alert: "No image found to generate story card."
    end
  end

  # GET /admin/articles/:id/story_video — download an animated MP4 story
  def story_video
    video_data = InstagramStoryVideoService.new(@article, **story_params).generate
    if video_data
      send_data video_data, type: "video/mp4",
                filename: "#{@article.slug}-story.mp4", disposition: "attachment"
    else
      redirect_to edit_admin_article_path(@article), alert: "No image found to generate story video."
    end
  end

  # POST /admin/articles/:id/share_instagram — generate the export, expose it
  # at a public URL, and publish it as an Instagram story via the Graph API.
  def share_instagram
    unless ENV["APPLICATION_HOST"].present?
      return render json: { error: "Set APPLICATION_HOST to a publicly reachable hostname (e.g. via ngrok in dev). Instagram must be able to download the exported file." }, status: :unprocessable_entity
    end

    media_type = params[:media_type].to_s # "image" or "video"

    export_path, _content_type, _ext =
      if media_type == "video"
        [ write_instagram_export(InstagramStoryVideoService.new(@article, **story_params).generate, "mp4"), "video/mp4", "mp4" ]
      else
        [ write_instagram_export(InstagramStoryService.new(@article, **story_params).generate, "png"), "image/png", "png" ]
      end

    return render json: { error: "No image found for this article." }, status: :unprocessable_entity unless export_path

    public_url = instagram_export_url(export_path)
    ig         = InstagramService.new
    media_id   = media_type == "video" ? ig.publish_video_story(media_url: public_url) : ig.publish_image_story(media_url: public_url)

    render json: { success: true, media_id: media_id }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  ensure
    File.delete(export_path) if export_path && File.exist?(export_path)
    purge_old_instagram_exports
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

  # Crop/overlay params sent by the story-preview Stimulus controller.
  def story_params
    {
      img_x: params[:img_x], img_y: params[:img_y],
      img_w: params[:img_w], img_h: params[:img_h],
      gradient_opacity: params[:gradient_opacity]
    }
  end

  INSTAGRAM_EXPORT_DIR = Rails.root.join("public", "instagram_exports")
  INSTAGRAM_EXPORT_TTL = 3600 # seconds — files older than this are purged

  def write_instagram_export(data, ext)
    return nil unless data
    FileUtils.mkdir_p(INSTAGRAM_EXPORT_DIR)
    path = INSTAGRAM_EXPORT_DIR.join("#{SecureRandom.uuid}.#{ext}")
    File.binwrite(path, data)
    path
  end

  def instagram_export_url(path)
    filename = File.basename(path)
    host     = ENV.fetch("APPLICATION_HOST")
    scheme   = Rails.env.production? ? "https" : request.protocol.delete_suffix("://")
    "#{scheme}://#{host}/instagram_exports/#{filename}"
  end

  def purge_old_instagram_exports
    return unless Dir.exist?(INSTAGRAM_EXPORT_DIR)
    Dir.glob(INSTAGRAM_EXPORT_DIR.join("*")).each do |f|
      File.delete(f) if File.mtime(f) < Time.current - INSTAGRAM_EXPORT_TTL
    end
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
