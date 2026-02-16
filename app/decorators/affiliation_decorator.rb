class AffiliationDecorator < ApplicationDecorator
  def detail(length: nil)
    "#{person.full_name}: #{title.presence || position} - #{organization.name}"
  end
end
