class Admin::TagsController < Admin::BaseController
  before_action :set_tag, only: %i[edit update destroy]

  def index
    @tags = Tag.order(created_at: :desc).page(params[:page]).per(10)
  end

  def new
    @tag = Tag.new
  end

  def edit
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to admin_tags_path, notice: t("admin.flash.created", model: t("admin.models_cap.tag"))
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @tag.update(tag_params)
      redirect_to admin_tags_path, notice: t("admin.flash.updated", model: t("admin.models_cap.tag"))
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path, status: :see_other, notice: t("admin.flash.deleted", model: t("admin.models_cap.tag"))
  end

  private

  def set_tag
    @tag = Tag.friendly.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name, :description, :featured)
  end
end
