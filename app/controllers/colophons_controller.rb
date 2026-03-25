class ColophonsController < ApplicationController
  def show
    @colophon = Colophon.instance
  end
end
