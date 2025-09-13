class MediaFile < ApplicationRecord
  belongs_to :report, optional: true
  belongs_to :workshop, optional: true
  belongs_to :workshop_log, optional: true

  FORM_FILE_CONTENT_TYPES = ["image/jpeg", "image/jpg", "image/png",
    "application/pdf", "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]

  if ENV["ACTIVE_STORAGE"].present?
    has_one_attached :file
    validates :file, content_type: FORM_FILE_CONTENT_TYPES
  else
    has_attached_file :file

    validates_attachment :file, content_type: {content_type: FORM_FILE_CONTENT_TYPES}
  end
end
