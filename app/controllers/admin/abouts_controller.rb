class Admin::AboutsController < Admin::BaseController
  def edit
    @about = About.instance
  end

  def update
    @about = About.instance
    if @about.update(about_params)
      redirect_to edit_admin_about_path, notice: "About page updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def about_params
    params.require(:about).permit(:content)
  end
end
