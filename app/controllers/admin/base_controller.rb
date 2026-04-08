class Admin::BaseController < ApplicationController
  include Authentication
  before_action :require_authentication
  layout "admin"

  rescue_from ActiveRecord::RecordNotFound do |e|
    Rails.logger.error "[Admin] RecordNotFound: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to admin_root_path, alert: "Record not found (#{e.message.truncate(80)})."
  end
end
