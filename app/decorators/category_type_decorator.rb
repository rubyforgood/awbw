class CategoryTypeDecorator < ApplicationDecorator
  def title
    name.humanize
  end

  def detail(length: nil)
  end
end
