class Attachment < ApplicationRecord
  belongs_to :owner, polymorphic: true

  ACCEPTED_CONTENT_TYPES = %w[application/pdf application/msword image/gif image/jpeg image/png].freeze
  has_one_attached :file
  validates :file, content_type: ACCEPTED_CONTENT_TYPES

  def name
    "Pdf Attachment"
  end
end
