class Admin::FlickrController < Admin::BaseController
  # GET /admin/flickr/albums
  def albums
    flickr = FlickrService.new
    sets   = flickr.albums
    render json: sets.map { |set|
      {
        id:          set.id,
        title:       set.title,
        photo_count: set.photos.to_i,
        cover_url:   flickr.cover_url(set)
      }
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /admin/flickr/import
  def import
    article     = Article.find(params[:article_id])
    photoset_id = params[:photoset_id].to_s
    return render json: { error: "missing photoset_id" }, status: :bad_request if photoset_id.blank?

    flickr   = FlickrService.new
    photos   = flickr.album_photos(photoset_id)
    imported = 0

    photos.each do |photo|
      url  = flickr.photo_download_url(photo)
      data = HTTParty.get(url)
      next unless data.success?
      article.photo_candidates.attach(
        io:           StringIO.new(data.body),
        filename:     "#{photo.id}.jpg",
        content_type: data.headers["content-type"]&.split(";")&.first || "image/jpeg"
      )
      imported += 1
    rescue => e
      Rails.logger.warn "Flickr import error for #{photo.id}: #{e.message}"
    end

    article.save(validate: false) if imported > 0

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
