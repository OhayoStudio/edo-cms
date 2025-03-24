class ArticlesTag < ApplicationRecord
  has_and_belongs_to_many :articles
  has_and_belongs_to_many :tags
end
