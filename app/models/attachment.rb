# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :owner, polymorphic: true

  has_attached_file :file
  validates_attachment :file, content_type: { content_type: ["application/pdf", "application/msword", "image/gif", "image/jpg", "image/jpeg", "image/png"] }

  def name
    "Pdf Attachment"
  end
end
