class WorkshopLogDecorator < ApplicationDecorator
  def detail(length: nil)
    length ? description&.truncate(length) : description
  end
end
