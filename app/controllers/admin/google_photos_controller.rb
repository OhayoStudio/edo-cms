class Admin::GooglePhotosController < Admin::BaseController
  PHOTOS_PICKER_BASE = "https://photospicker.googleapis.com/v1"

  # POST /admin/google_photos/open
  # Body: { access_token: }
  def open
    access_token = params[:access_token].to_s
    return render json: { error: "missing access_token" }, status: :bad_request if access_token.blank?

    resp = HTTParty.post(
      "#{PHOTOS_PICKER_BASE}/sessions",
      headers: { "Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json" },
      body: "{}"
    )

    unless resp.success?
      Rails.logger.warn "Google Photos session creation failed: #{resp.code} #{resp.body}"
      return render json: { error: resp.parsed_response }, status: resp.code
    end

    render json: { session_id: resp["id"], picker_uri: resp["pickerUri"] }
  end

  # POST /admin/google_photos/import
  # Body: { article_id:, access_token:, session_id: }
  def import
    article      = Article.find(params[:article_id])
    access_token = params[:access_token].to_s
    session_id   = params[:session_id].to_s
    return render json: { error: "missing params" }, status: :bad_request if access_token.blank? || session_id.blank?

    # Check session is complete
    session = HTTParty.get(
      "#{PHOTOS_PICKER_BASE}/sessions/#{session_id}",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    unless session.success? && session["mediaItemsSet"]
      return render json: { imported: 0, thumbnails: [] }
    end

    # List all media items (paginated)
    items      = []
    page_token = nil
    loop do
      query = { sessionId: session_id, pageSize: 100 }
      query[:pageToken] = page_token if page_token
      resp = HTTParty.get(
        "#{PHOTOS_PICKER_BASE}/mediaItems",
        query:   query,
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
      break unless resp.success?
      items.concat(Array(resp["mediaItems"]))
      page_token = resp["nextPageToken"]
      break if page_token.nil?
    end
    # Download and attach images
    imported = 0
    items.each do |item|
      media_file = item["mediaFile"]
      next unless media_file
      next unless media_file["mimeType"]&.start_with?("image/")
      data = HTTParty.get(
        "#{media_file["baseUrl"]}=w2048-h2048",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
      next unless data.success?
      article.photo_candidates.attach(
        io:           StringIO.new(data.body),
        filename:     "#{item["id"]}.jpg",
        content_type: media_file["mimeType"]
      )
      imported += 1
    rescue => e
      Rails.logger.warn "Google Photos import error: #{e.message}"
    end

    article.save(validate: false) if imported > 0

    # Cleanup session
    HTTParty.delete(
      "#{PHOTOS_PICKER_BASE}/sessions/#{session_id}",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )

    thumbnails = article.photo_candidates.last(imported).map do |blob|
      {
        id:           blob.id,
        url:          url_for(blob.variant(resize_to_limit: [ 96, 96 ])),
        original_url: admin_blob_proxy_path(blob.blob.signed_id)
      }
    end

    render json: { imported: imported, thumbnails: thumbnails }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Article not found" }, status: :not_found
  end
end
