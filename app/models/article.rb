class Article < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  # Active Storage and Action Text
  has_rich_text :content
  has_one_attached :featured_image
  
  # Relationships
  belongs_to :author
  belongs_to :category
  has_and_belongs_to_many :tags

  # Enums
  enum :status, %i(draft review published archived)

  # Validations
  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :slug, presence: true, uniqueness: true
  validates :meta_description, length: { maximum: 160 }
  validates :excerpt, length: { maximum: 500 }
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
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :published, -> { where.not(published_at: nil).where(status: :published) }
  scope :featured, -> { where(featured: true) }

  private

  def set_default_status
    self.status ||= :draft
  end

  def generate_slug
    self.slug = title.parameterize if title.present?
  end

  def calculate_reading_time
    return unless content.present?
    words_per_minute = 200
    word_count = content.to_plain_text.split.size
    self.reading_time = (word_count / words_per_minute.to_f).ceil
  end
end
