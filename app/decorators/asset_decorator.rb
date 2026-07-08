class AssetDecorator < ApplicationDecorator
  delegate_all

  # "Primary asset", "Gallery asset", "Rich text asset"
  def type_label
    object.type.to_s.underscore.humanize
  end

  # Sentence-cased model name the asset is attached to ("Community news").
  def owner_type_label
    return "Unattached" if object.owner_type.blank?

    object.owner_type.underscore.humanize
  end

  # Best-effort human name for the specific owner record.
  def owner_name
    return if object.owner.blank?

    object.owner.try(:title).presence || object.owner.try(:name).presence
  end

  # A path to the owning record, or nil when it can't be routed.
  def owner_path
    return if object.owner.blank?

    h.polymorphic_path(object.owner)
  rescue NoMethodError, ActionController::UrlGenerationError
    nil
  end

  def filename
    object.file.filename.to_s if object.file.attached?
  end

  def content_type_label
    return unless object.file.attached?

    Asset::CONTENT_TYPE_LABELS[object.file.content_type] || object.file.content_type
  end

  def image?
    object.file.attached? && object.file.content_type.to_s.start_with?("image/")
  end

  def thumbnail
    object.file.variant(:thumbnail) if image?
  end
end
