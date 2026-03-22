class Admin::BaseController < ApplicationController
  include Authentication
  before_action :require_authentication
  layout "admin"
end
