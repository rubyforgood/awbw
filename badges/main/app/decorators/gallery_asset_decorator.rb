class GalleryAssetDecorator < ApplicationDecorator
  def title
    object.title
  end

  def detail(length: nil)
    ""
  end

  def display_image
    return file if file&.attached?
    default_display_image
  end
end
