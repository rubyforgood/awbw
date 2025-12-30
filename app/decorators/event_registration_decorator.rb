class EventRegistrationDecorator < ApplicationDecorator
  def title
    name
  end

  def detail
  end

  def default_display_image
    return event.main_image.file if event.respond_to?(:main_image) && event.main_image&.file&.attached?
    "theme_default.png"
  end
end
