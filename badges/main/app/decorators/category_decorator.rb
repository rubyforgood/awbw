class CategoryDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    "#{category_type.name}: #{name}"
  end
end
