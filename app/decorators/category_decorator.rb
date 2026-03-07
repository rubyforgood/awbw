class CategoryDecorator < ApplicationDecorator
  def title
    name
  end

  def title_spanish
    name_spanish.presence || name
  end

  def detail(length: nil)
    "#{category_type.name}: #{name}"
  end

  def detail_spanish(length: nil)
    type_label = category_type.name_spanish.presence || category_type.name
    "#{type_label}: #{name_spanish.presence || name}"
  end
end
