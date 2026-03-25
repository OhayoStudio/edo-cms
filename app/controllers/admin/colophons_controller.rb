class Admin::ColophonsController < Admin::BaseController
  def edit
    @colophon = Colophon.instance
  end

  def update
    @colophon = Colophon.instance
    if @colophon.update(colophon_params)
      redirect_to edit_admin_colophon_path, notice: "Colophon updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def colophon_params
    params.require(:colophon).permit(:content)
  end
end
