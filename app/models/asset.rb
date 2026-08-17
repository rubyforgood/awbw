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
    "application/msword", # Word .doc
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document", # Word .docx
    "application/vnd.oasis.opendocument.text" # Word document .odt
  ].freeze

  # Ceiling on a single upload. Uploads now reach us from the public event
  # registration form, so this is the backstop against one enormous file
  # filling storage — generous enough for a photo or a scanned document.
  MAX_FILE_SIZE = 25.megabytes


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
    "application/msword" => "DOC",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "DOCX",
    "application/vnd.oasis.opendocument.text" => "ODT"
  }.freeze

  def self.accept_attribute
    self::ACCEPTED_CONTENT_TYPES.join(",")
  end

  def self.accepted_types_label
    self::ACCEPTED_CONTENT_TYPES.map { |ct| CONTENT_TYPE_LABELS[ct] || ct }.join(", ")
  end

  def self.max_file_size_label
    ActiveSupport::NumberHelper.number_to_human_size(MAX_FILE_SIZE)
  end

  belongs_to :owner, polymorphic: true, optional: true, touch: true
  belongs_to :report, optional: true

  has_one_attached :file, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :webp,
      saver: { quality: 80 }
    attachable.variant :card,
      resize_to_limit: [ 1200, 1200 ],
      format: :webp,
      saver: { quality: 80 }
  end
  validate :file_type
  validate :file_size

  private

  def file_type
    return unless file.attached?

    allowed_types = self.class::ACCEPTED_CONTENT_TYPES

    unless allowed_types.include?(file.content_type)
      errors.add(:file, "type not accepted")
    end
  end

  def file_size
    return unless file.attached?
    return if file.byte_size.to_i <= MAX_FILE_SIZE

    errors.add(:file, "is too large (maximum #{self.class.max_file_size_label})")
  end
end
