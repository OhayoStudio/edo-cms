class PanoramicImage < ApplicationRecord
  include ActionText::Attachable

  has_one_attached :image

  validates :image, presence: true

  def to_attachable_partial_path
    "action_text/attachables/panoramic_image"
  end
end
