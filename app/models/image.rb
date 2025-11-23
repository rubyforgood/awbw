class Image < ApplicationRecord
  self.inheritance_column = :type
<<<<<<< HEAD
=======

>>>>>>> b3025845 (Change Image to STI so MainImage can be separate from the rest of the images, now named GalleryImage)
  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true
  # Images
  has_one_attached :file

<<<<<<< HEAD
=======
  has_one_attached :file

>>>>>>> b3025845 (Change Image to STI so MainImage can be separate from the rest of the images, now named GalleryImage)
  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif"].freeze
  validates :file,
            content_type: ACCEPTED_CONTENT_TYPES
end
