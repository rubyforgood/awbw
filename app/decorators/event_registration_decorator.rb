class EventRegistrationDecorator < ApplicationDecorator
  def title
    name
  end

  def detail
  end

  def default_display_image
    return event.primary_asset.file if event.respond_to?(:primary_asset) && event.primary_asset&.file&.attached?
    "theme_default.png"
  end
end
