LexxyPhotos.configure do |c|
  c.record_finder = ->(id) { Article.friendly.find(id) }
  c.before_action :require_authentication
end

Rails.application.config.to_prepare do
  LexxyPhotos::ApplicationController.include(Authentication)
end
