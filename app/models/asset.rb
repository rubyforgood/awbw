class Asset < ApplicationRecord
  self.inheritance_column = :type

  ACCEPTED_CONTENT_TYPES = [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/heic",
    "image/heif",
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
    DownloadableAsset
    GalleryAsset
  ].freeze

  def self.allowed_types_for_owner(owner)
    return TYPES unless owner

    owner_name =
      if owner.respond_to?(:owner_class)
        owner.owner_class
      else
        Draper.undecorate(owner).class.name
      end

    case owner_name
    when "Workshop", "WorkshopVariation", "WorkshopIdea", "Story", "StoryIdea", "CommunityNews", "Event"
      TYPES - [ "DownloadableAsset" ]
    else
      TYPES
    end
  end

  CONTENT_TYPE_LABELS = {
    "image/jpeg" => "JPG",
    "image/png" => "PNG",
    "image/gif" => "GIF",
    "image/webp" => "WebP",
    "image/heic" => "HEIC",
    "image/heif" => "HEIF",
    "application/pdf" => "PDF",
    "application/zip" => "ZIP",
    "application/msword" => "DOC",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "DOCX",
    "application/vnd.oasis.opendocument.text" => "ODT",
    "text/html" => "HTML"
  }.freeze

  def self.accept_attribute
    self::ACCEPTED_CONTENT_TYPES.join(",")
  end

  def self.accepted_types_label
    self::ACCEPTED_CONTENT_TYPES.map { |ct| CONTENT_TYPE_LABELS[ct] || ct }.join(", ")
  end

  belongs_to :owner, polymorphic: true, optional: true, touch: true
  belongs_to :report, optional: true

  has_one_attached :file, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :webp,
      saver: { quality: 80 }
  end
  validate :file_type

  private

  def file_type
    return unless file.attached?

    allowed_types = self.class::ACCEPTED_CONTENT_TYPES

    unless allowed_types.include?(file.content_type)
      errors.add(:file, "type not accepted")
    end
  end
end
