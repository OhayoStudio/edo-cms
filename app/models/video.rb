class Video < ApplicationRecord
    extend FriendlyId
    friendly_id :title, use: :slugged

    has_one_attached :featured_image do |attachable|
      attachable.variant :hero,  resize_to_limit: [ 1600, 900 ], saver: { quality: 95 }
      attachable.variant :thumb, resize_to_limit: [ 600, 400 ], saver: { quality: 90 }
      attachable.variant :og,    resize_to_limit: [ 1200, 630 ], format: :webp, saver: { quality: 85 }
    end
    has_one :story, as: :storyable

    validates :title, presence: true
    validates :description, presence: true
    validates :url, presence: true
    validates :featured_image, presence: true

    def should_generate_new_friendly_id?
        title_changed?
    end

    def to_s
        title
    end

    def to_param
        slug
    end

    def thumbnail
        featured_image.variant(:thumb)
    end

    def thumbnail_url
        # get url for featured_image
        Rails.application.routes.url_helpers.rails_blob_url(featured_image, only_path: true)
    end
end
