class GalleryAssetDecorator < ApplicationDecorator
  def title
    object.title
  end

  def detail(length: nil)
    ""
  end

  def display_image
    return file if file&.attached?
    return owner.images.first.file if owner.respond_to?(:images) && owner.images.first&.file&.attached?
    return owner.attachments.first.file if owner.respond_to?(:attachments) && owner.attachments.first&.file&.attached?
    default_display_image
  end
end
