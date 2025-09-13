class Attachment < ApplicationRecord
  belongs_to :owner, polymorphic: true

  ACCEPTED_CONTENT_TYPES = %w[application/pdf application/msword image/gif image/jpeg image/png].freeze

  if ENV["ACTIVE_STORAGE"].present?
    has_one_attached :file
    validates :file, content_type: ACCEPTED_CONTENT_TYPES
  else
    has_attached_file :file
    validates_attachment :file, content_type: {content_type: ACCEPTED_CONTENT_TYPES}
  end

  def name
    "Pdf Attachment"
  end
end
