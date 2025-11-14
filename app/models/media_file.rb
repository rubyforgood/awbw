class MediaFile < ApplicationRecord
  belongs_to :report, optional: true
  belongs_to :workshop, optional: true
  belongs_to :workshop_log, optional: true

  FORM_FILE_CONTENT_TYPES = ["image/jpeg", "image/png",
    "application/pdf", "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
  has_one_attached :file
  validates :file, content_type: FORM_FILE_CONTENT_TYPES
end
