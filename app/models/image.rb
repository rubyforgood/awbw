class Image < ApplicationRecord
  self.inheritance_column = :type

  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true
  # Images
  has_one_attached :file

  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif"].freeze
  validates :file, content_type: ACCEPTED_CONTENT_TYPES
end
