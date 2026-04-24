require "lexxy_photos"

LexxyPhotos.configure do |c|
  c.record_finder = ->(id) { Article.friendly.find(id) }
  c.before_action :require_authentication
end
