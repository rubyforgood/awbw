class MediaFile < ApplicationRecord
  belongs_to :report, optional: true
  belongs_to :workshop_log, optional: true
  # Images
  has_one_attached :file

  FORM_FILE_CONTENT_TYPES = ["image/jpeg", "image/png",
    "application/pdf", "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
  validates :file, content_type: FORM_FILE_CONTENT_TYPES
end
