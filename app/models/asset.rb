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

  belongs_to :owner, polymorphic: true, optional: true, touch: true
  belongs_to :report, optional: true

  # Admin image index: keyword search across title, attached filename, and the
  # type of record the asset is attached to (owner_type). One attachment per
  # asset (has_one_attached), so the left join never multiplies rows.
  def self.search(query)
    return all if query.blank?

    like = "%#{sanitize_sql_like(query)}%"
    left_joins(:file_blob).where(
      "assets.title LIKE :like OR assets.owner_type LIKE :like OR active_storage_blobs.filename LIKE :like",
      like: like
    )
  end

  # Distinct STI types present, for the admin index type filter.
  def self.present_types
    distinct.pluck(:type).compact.sort
  end

  # Distinct owner model names present, for the admin index "attached to" filter.
  def self.present_owner_types
    distinct.pluck(:owner_type).compact.sort
  end

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
