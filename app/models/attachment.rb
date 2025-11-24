class Attachment < ApplicationRecord
  belongs_to :owner, polymorphic: true
  # Images
  has_one_attached :file

  # Validations
  ACCEPTED_CONTENT_TYPES = %w[application/pdf application/msword image/gif image/jpeg image/png].freeze
  validates :file, content_type: ACCEPTED_CONTENT_TYPES

  def name
    "Pdf Attachment"
  end
end
