class AboutController < ApplicationController
  def index
    @about = About.instance
  end
end
