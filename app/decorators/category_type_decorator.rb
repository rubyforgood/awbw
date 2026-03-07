class CategoryTypeDecorator < ApplicationDecorator
  def title
    name.titleize
  end

  def title_spanish
    name_spanish.presence&.titleize || name.titleize
  end

  def detail(length: nil)
  end
end
