class CategoryTypeDecorator < ApplicationDecorator
  def page_title_label
    title
  end

  def title
    name.underscore.humanize
  end

  def detail(length: nil)
  end
end
