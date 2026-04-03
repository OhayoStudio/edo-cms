class Admin::GooglePhotosController < Admin::BaseController
  # POST /admin/google_photos/import
  # Body: { article_id:, access_token:, photos: [ { file_id:, filename:, mime_type: }, ... ] }
  def import
    article      = Article.find(params[:article_id])
    access_token = params[:access_token].to_s
    return render json: { error: "missing access_token" }, status: :bad_request if access_token.blank?

    imported = 0

    Array(params[:photos]).each do |photo|
      url  = "https://www.googleapis.com/drive/v3/files/#{photo[:file_id]}?alt=media"
      data = HTTParty.get(url, headers: { "Authorization" => "Bearer #{access_token}" })

      unless data.success?
        Rails.logger.warn "Google Picker download failed for #{photo[:filename]}: HTTP #{data.code}"
        next
      end

      content_type = data.headers["content-type"]&.split(";")&.first || "image/jpeg"
      article.photo_candidates.attach(
        io:           StringIO.new(data.body),
        filename:     photo[:filename].presence || "photo.jpg",
        content_type: content_type
      )
      imported += 1
    rescue => e
      Rails.logger.warn "Google Picker import error for #{photo[:filename]}: #{e.message}"
    end

    article.save(validate: false) if imported > 0

    thumbnails = article.photo_candidates.last(imported).map do |blob|
      {
        id:           blob.id,
        url:          url_for(blob.variant(resize_to_limit: [ 96, 96 ])),
        original_url: url_for(blob)
      }
    end

    render json: { imported: imported, thumbnails: thumbnails }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Article not found" }, status: :not_found
  end
end
