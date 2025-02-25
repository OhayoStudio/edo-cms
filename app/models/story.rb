class Story < ApplicationRecord
  belongs_to :storyable, polymorphic: true
end
