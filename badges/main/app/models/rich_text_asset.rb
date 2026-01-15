class RichTextAsset < Asset
  include ActionText::Attachable

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

  has_many :action_text_mentions,
           as: :mentionable,
           dependent: :destroy

  has_many :action_text_rich_texts,
           through: :action_text_mentions

  ## ActionText:Attachable
  def attachable_content_type
    "application/vnd.active_record.asset"
  end
  # Used when editing
  def to_trix_content_attachment_partial_path
    "rich_text_asset_mentions/trix_content_attachment"
  end

  # Used when displaying
  def to_attachable_partial_path
    @record = self
    "shared/mentions/attachable"
  end
end
