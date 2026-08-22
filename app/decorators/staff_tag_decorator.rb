class StaffTagDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    description
  end

  def status_label
    archived? ? "Archived" : "Active"
  end
end
