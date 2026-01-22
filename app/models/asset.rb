class Asset < ApplicationRecord
  self.inheritance_column = :type

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


  # Form selection
  TYPES = %w[
    PrimaryAsset
    ThumbnailAsset
    GalleryAsset
  ].freeze

  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :report, optional: true

  has_one_attached :file, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :jpeg,
      saver: { quality: 80 }
  end
  validate :file_type

  private

  def file_type
    return unless file.attached?

    allowed_types =
      case type
      when "PrimaryAsset"
        PrimaryAsset::ACCEPTED_CONTENT_TYPES
      when "ThumbnailAsset"
        ThumbnailAsset::ACCEPTED_CONTENT_TYPES
      else
        ACCEPTED_CONTENT_TYPES
      end

    unless allowed_types.include?(file.content_type)
      errors.add(:file, "type is not allowed for #{type.underscore.humanize}")
    end
  end
end
