class Admin::PanoramicImagesController < Admin::BaseController
  before_action :set_panoramic_image, only: %i[ show edit update destroy ]

  CONTENT_TYPE = "application/vnd.edo-cms.panoramic-image"

  def index
    @panoramic_images = PanoramicImage.with_attached_image.order(created_at: :desc).page(params[:page])

    respond_to do |format|
      format.html
      format.json do
        page = params[:page].to_i.positive? ? params[:page].to_i : 1
        per_page = params[:per_page].to_i.positive? ? params[:per_page].to_i : 10

        images = PanoramicImage.with_attached_image.order(created_at: :desc).page(page).per(per_page)

        render json: {
          panoramic_images: images.filter_map { |img| serialize_for_modal(img) if img.image.attached? },
          has_more: images.next_page.present?
        }
      end
    end
  end

  def show
  end

  def new
    @panoramic_image = PanoramicImage.new
  end

  def edit
  end

  def create
    @panoramic_image = PanoramicImage.new(panoramic_image_params)

    if @panoramic_image.save
      redirect_to admin_panoramic_image_path(@panoramic_image), notice: "Panoramic image created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @panoramic_image.update(panoramic_image_params)
      redirect_to admin_panoramic_image_path(@panoramic_image), notice: "Panoramic image updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @panoramic_image.destroy!
    redirect_to admin_panoramic_images_path, status: :see_other, notice: "Panoramic image deleted."
  end

  private

  def set_panoramic_image
    @panoramic_image = PanoramicImage.find(params[:id])
  end

  def panoramic_image_params
    params.expect(panoramic_image: [ :image ])
  end

  # Builds the JSON payload consumed by the modal in the article form.
  # `content` is the HTML that Lexxy stores in the action-text-attachment's
  # `content` attribute — it must match what `_panoramic_image.html.erb` emits
  # on the public render path, so we render that same partial here.
  def serialize_for_modal(img)
    {
      id: img.id,
      image_url: url_for(img.image),
      sgid: img.attachable_sgid,
      content_type: CONTENT_TYPE,
      content: render_to_string(
        partial: "action_text/attachables/panoramic_image",
        locals: { panoramic_image: img },
        formats: [ :html ]
      ).gsub(/<!--.*?-->/m, "").squish,
      created_at: img.created_at.strftime("%b %d, %Y")
    }
  end
end
