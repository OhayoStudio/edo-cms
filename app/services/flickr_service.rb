class FlickrService
  def initialize
    FlickRaw.api_key       = ENV.fetch("FLICKR_API_KEY")
    FlickRaw.shared_secret = ENV.fetch("FLICKR_API_SECRET")
    @flickr = FlickRaw::Flickr.new
    @flickr.access_token  = ENV.fetch("FLICKR_ACCESS_TOKEN")
    @flickr.access_secret = ENV.fetch("FLICKR_ACCESS_TOKEN_SECRET")
    @nsid = ENV.fetch("FLICKR_USER_NSID")
  end

  def albums
    sets = []
    page = 1
    loop do
      resp = @flickr.photosets.getList(user_id: @nsid, page: page, per_page: 500)
      sets.concat(resp.photoset)
      break if page >= resp.pages.to_i
      page += 1
    end
    sets
  end

  def album_photos(photoset_id)
    photos = []
    page   = 1
    loop do
      resp = @flickr.photosets.getPhotos(
        photoset_id: photoset_id,
        user_id:     @nsid,
        extras:      "url_b,url_q",
        per_page:    500,
        page:        page
      )
      photos.concat(resp.photo)
      break if page >= resp.pages.to_i
      page += 1
    end
    photos
  end

  def cover_url(set)
    "https://live.staticflickr.com/#{set.server}/#{set.primary}_#{set.secret}_z.jpg"
  end

  def photo_download_url(photo)
    photo.respond_to?(:url_b) && photo.url_b.present? ? photo.url_b :
      "https://live.staticflickr.com/#{photo.server}/#{photo.id}_#{photo.secret}_b.jpg"
  end
end
