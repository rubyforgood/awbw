class CategoryTypeDecorator < ApplicationDecorator
  def title
    name.titleize
  end

  def detail(length: nil)
  end
end
