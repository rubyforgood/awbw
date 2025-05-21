class MediaFile < ApplicationRecord
  belongs_to :report
  belongs_to :workshop
  belongs_to :workshop_log

  has_attached_file :file

  FORM_FILE_CONTENT_TYPES = ["image/jpeg", "image/jpg", "image/png",
                             "application/pdf", "application/msword",
                             "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                             "application/vnd.ms-excel",
                             "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]

   validates_attachment :file, content_type: { content_type:  FORM_FILE_CONTENT_TYPES }
end
