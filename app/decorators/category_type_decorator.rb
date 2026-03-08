class CategoryTypeDecorator < ApplicationDecorator
  def title
    name.underscore.humanize
  end

  def detail(length: nil)
  end
end
