class StoryDecorator < Draper::Decorator
  delegate_all

  def description
    body.truncate(50)
  end

  def inactive?
    !published?
  end

  def workshop_title
    workshop&.title || external_workshop_title
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
