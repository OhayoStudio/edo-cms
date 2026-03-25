class Colophon < ApplicationRecord
  has_rich_text :content

  def self.instance
    first_or_create!
  end
end
