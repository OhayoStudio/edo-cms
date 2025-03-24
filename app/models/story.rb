class Story < ApplicationRecord
  belongs_to :storyable, polymorphic: true

  scope :published, -> { where(is_published: true) }
  scope :recent, -> { order(published_at: :desc) }
  scope :with_slug, -> { where.not(slug: nil) }
  scope :limit_3, -> { limit(3) }
  scope :limit_4, -> { limit(4) }
  scope :top, -> { where(is_top: true) }

  def to_param
    slug
  end
end
