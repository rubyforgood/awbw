class RichTextAsset < Asset
  ACCEPTED_CONTENT_TYPES = [
    "image/jpeg",
    "image/png",
    "image/gif",
    "application/pdf",
    "application/zip",
    "application/msword", # Word .doc
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document", # Word .docx
    "application/vnd.oasis.opendocument.text", # Word document .odt
    "text/html"
  ].freeze

  validates :file, content_type: ACCEPTED_CONTENT_TYPES
end
