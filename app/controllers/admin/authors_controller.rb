class Admin::AuthorsController < Admin::BaseController
  before_action :set_author, only: %i[edit update destroy]

  def index
    @authors = Author.not_deleted
                     .order(:last_name, :first_name)
                     .page(params[:page]).per(20)
  end

  def new
    @author = Author.new
  end

  def edit
  end

  def create
    @author = Author.new(author_params)
    if @author.save
      redirect_to admin_authors_path, notice: "Author created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @author.update(author_params)
      redirect_to admin_authors_path, notice: "Author updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @author.soft_delete
    respond_to do |format|
      format.json { head :no_content }
      format.any  { redirect_to admin_authors_path, status: :see_other, notice: "Author deleted." }
    end
  end

  private

  def set_author
    @author = Author.find(params[:id])
  end

  def author_params
    params.require(:author).permit(
      :first_name, :last_name, :email, :bio,
      :website, :twitter_handle, :github_username, :linkedin_url,
      :role, :status, :avatar
    )
  end
end
