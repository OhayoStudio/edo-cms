class Admin::BlobsController < Admin::BaseController
  def show
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    send_data blob.download, type: blob.content_type, disposition: :inline
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    head :not_found
  end
end
