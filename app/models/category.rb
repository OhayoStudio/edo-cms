# app/models/category.rb
class Category < ApplicationRecord
    extend FriendlyId
    friendly_id :name, use: :slugged

    paginates_per 3
    max_paginates_per 3

    # Self Join for hierarchical categories
    belongs_to :parent, class_name: "Category", optional: true
    has_many :subcategories, class_name: "Category", foreign_key: "parent_id"

    # Relationships
    has_many :articles, dependent: :nullify

    # Enums
    enum :status, {
      active: 0,
      inactive: 1
    }

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :slug, presence: true, uniqueness: true
    validates :description, presence: true
    validates :meta_title, length: { maximum: 60 }
    validates :meta_description, length: { maximum: 160 }

    # Callbacks
    before_validation :generate_slug

    # Scopes
    scope :root_categories, -> { where(parent_id: nil) }
    scope :featured, -> { where(featured: true) }
    scope :active, -> { where(status: :active) }
    scope :not_deleted, -> { where(deleted_at: nil) }

    private

    def generate_slug
      self.slug = name.parameterize if name.present?
    end
end
