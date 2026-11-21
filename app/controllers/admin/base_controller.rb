class Admin::BaseController < ApplicationController
  include Authentication
  before_action :require_authentication
  layout "admin"

  rescue_from ActiveRecord::RecordNotFound do |e|
    Rails.logger.error "[Admin] RecordNotFound: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to admin_root_path, alert: t("admin.flash.record_not_found", detail: e.message.truncate(80))
  end

  private

  # A failed save drops the files just picked: the browser can't refill a file
  # field. Store them now, so the re-rendered form can show them and send them
  # back by reference (admin/shared/_kept_upload). A file left behind when the
  # form is abandoned stays as an unattached blob.
  def keep_uploads(record)
    record.attachment_changes.each_value do |change|
      next unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)
      next if change.blob.persisted?

      change.upload
      change.blob.save!
    end
  end
end
