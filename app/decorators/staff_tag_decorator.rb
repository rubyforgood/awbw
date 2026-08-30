class StaffTagDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    description
  end

  def status_label
    published? ? "Published" : "Unpublished"
  end
end
