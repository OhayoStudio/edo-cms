class Colophon < ApplicationRecord
  include LocalizedContent
  has_localized_content :content

  def self.instance
    first_or_create!
  end
end
