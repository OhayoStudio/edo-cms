class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: %i[edit update destroy]

  def index
    @categories = Category.includes(:parent)
                           .order(created_at: :desc)
                           .page(params[:page]).per(10)
  end

  def new
    @category = Category.new
  end

  def edit
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to admin_categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: "Category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy!
    redirect_to admin_categories_path, status: :see_other, notice: "Category deleted."
  end

  private

  def set_category
    @category = Category.friendly.find(params[:id])
  end

  def category_params
    params.require(:category).permit(
      :name, :description, :meta_title, :meta_description,
      :parent_id, :status, :featured
    )
  end
end
