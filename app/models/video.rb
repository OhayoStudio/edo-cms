class Video < ApplicationRecord
    extend FriendlyId
    friendly_id :title, use: :slugged

    has_one_attached :featured_image
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
        featured_image.variant(resize: "300x300!").processed
    end

    def thumbnail_url
        # get url for featured_image
        Rails.application.routes.url_helpers.rails_blob_url(featured_image, only_path: true)
    end
end
