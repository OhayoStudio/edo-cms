class Author < ApplicationRecord
  # Active Storage
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 128, 128 ], format: :webp
  end

  # Relationships
  has_many :articles, dependent: :nullify

  # Enums
  enum :status, %i[active inactive]


  enum :role, %i[
    writer
    editor
    admin
    ]

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true,
                   uniqueness: true,
                   format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :slug, presence: true, uniqueness: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp },
                     allow_blank: true

  # Callbacks
  before_validation :generate_slug

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    full_name
  end

  def soft_delete
    update(deleted_at: Time.current, status: :inactive)
  end

  def article_count
    articles.published.count
  end

  private

  def generate_slug
    self.slug = full_name.parameterize if first_name_changed? || last_name_changed?
  end
end
