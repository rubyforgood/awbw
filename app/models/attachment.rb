class Attachment < ApplicationRecord
  belongs_to :owner, polymorphic: true

  if ENV["ACTIVE_STORAGE"].present?
    has_one_attached :file
  else
    has_attached_file :file
    validates_attachment :file, content_type: {content_type: %w[application/pdf application/msword image/gif image/jpg image/jpeg image/png]}
  end

  def name
    "Pdf Attachment"
  end
end
