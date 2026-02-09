class WorkshopVariationIdeaDecorator < ApplicationDecorator
  def detail(length: nil)
    length ? description&.truncate(length) : description
  end

  def default_display_image
    "workshop_default.jpg"
  end
end
