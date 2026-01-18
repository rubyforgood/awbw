class ApplicationDecorator < Draper::Decorator
  delegate_all

  def display_image
    return thumbnail_asset.file if object.respond_to?(:thumbnail_asset) && thumbnail_asset&.file&.attached?
    return primary_asset.file if object.respond_to?(:primary_asset) && primary_asset&.file&.attached?
    return gallery_assets.first.file if object.respond_to?(:gallery_assets) && gallery_assets.first&.file&.attached?
    return images.first.file if object.respond_to?(:images) && images.first&.file&.attached?
    return attachments.first.file if object.respond_to?(:attachments) && attachments.first&.file&.attached?
    default_display_image
  end

  def default_display_image
    "theme_default.png"
  end

  def link_target
    h.polymorphic_path(object)
  end

  def external_link?
    false
  end
end
