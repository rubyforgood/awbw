class Image < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true

  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif"].freeze
  has_one_attached :file
  validates :file, content_type: ACCEPTED_CONTENT_TYPES
end
