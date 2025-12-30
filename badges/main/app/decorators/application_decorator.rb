class ApplicationDecorator < Draper::Decorator
  delegate_all

  def display_image
    return main_image.file if object.respond_to?(:main_image) && main_image&.file&.attached?
    return gallery_images.first.file if object.respond_to?(:gallery_images) && gallery_images.first&.file&.attached?
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
