class CommunityNewsDecorator < ApplicationDecorator
  def detail(length: nil)
    length ? body&.truncate(length) : body
  end

  def inactive?
    !published?
  end

  def main_image_url
    if main_image&.file&.attached?
      Rails.application.routes.url_helpers.url_for(main_image.file)
    elsif gallery_images.first&.file&.attached?
      Rails.application.routes.url_helpers.url_for(gallery_images.first.file)
    else
      ActionController::Base.helpers.asset_path("theme_default.png")
    end
  end

end
