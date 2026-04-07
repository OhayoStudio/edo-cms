class AuthorsController < ApplicationController
  # GET /authors/:id
  def show
    @author = Author.find(params[:id])
  end
end
