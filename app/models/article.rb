class Article < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  paginates_per 10
  max_paginates_per 10

  # Active Storage and Action Text
  has_rich_text :content
  has_one_attached :featured_image

  # Relationships
  belongs_to :author
  belongs_to :category
  has_and_belongs_to_many :tags
  has_one :story, as: :storyable

  # Enums
  enum :status, %i[draft review published archived]

  # Validations
  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :slug, presence: true, uniqueness: true
  validates :meta_description, length: { maximum: 160 }
  validates :excerpt, length: { maximum: 150 }
  validates :content, presence: true
  validates :reading_time, numericality: { only_integer: true, greater_than: 0 }
  # validates :view_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :published_at, presence: true, if: -> { status == :published }
  # validates :featured_image, content_type: %i(png jpg jpeg), size: { less_than: 5.megabytes }

  # Callbacks
  before_validation :generate_slug
  before_save :calculate_reading_time
  after_initialize :set_default_status, if: :new_record?

  # Scopes
  scope :published, -> { where.not(published_at: nil).where(status: :published) }
  scope :featured, -> { where(featured: true) }

  def related_articles(limit = 3)
    Article.published
           .where(category_id: category_id)
           .where.not(id: id)
           .order(published_at: :desc)
           .limit(limit)
  end

  def tag_related_articles(limit = 3)
    Article.published
           .joins(:tags)
           .where(tags: { id: tags.pluck(:id) })
           .where.not(id: id)
           .distinct
           .order(published_at: :desc)
           .limit(limit)
  end
  #

  private

  def set_default_status
    self.status ||= :draft
  end

  def generate_slug
    self.slug = title.parameterize if title.present?
  end

  def calculate_reading_time
    if content.present? && content.body.present? && content.body.to_plain_text.present?
      words_per_minute = 200
      word_count = content.to_plain_text.split.size
      self.reading_time = (word_count.to_f / words_per_minute).ceil
      self.reading_time = 1 if self.reading_time < 1 # Ensure it's at least 1
    else
      self.reading_time = 1 # Default to 1 minute if no content or content is blank
    end
  end
end
