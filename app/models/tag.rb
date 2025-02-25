# app/models/tag.rb
class Tag < ApplicationRecord
    # Relationships
    has_and_belongs_to_many :articles
  
    # Validations
    validates :name, presence: true, uniqueness: true
    validates :slug, presence: true, uniqueness: true
    validates :meta_title, length: { maximum: 60 }
    validates :meta_description, length: { maximum: 160 }
  
    # Callbacks
    before_validation :generate_slug
  
    # Scopes
    scope :featured, -> { where(featured: true) }
    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :with_articles, -> { joins(:articles).distinct }
  
    # Methods
    def article_count
      articles.published.count
    end
  
    private
  
    def generate_slug
      self.slug = name.parameterize if name_changed?
    end
  end
  