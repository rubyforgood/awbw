class GalleryAssetDecorator < ApplicationDecorator
  def title
    title
  end

  def detail(length: nil)
    ""
  end

  def display_image
    return file&.attached?
    default_display_image
  end
end
