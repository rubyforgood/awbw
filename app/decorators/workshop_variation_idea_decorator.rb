class WorkshopVariationIdeaDecorator < ApplicationDecorator
  def detail(length: nil)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def default_display_image
    "workshop_default.jpg"
  end
end
