class AffiliationDecorator < ApplicationDecorator
  def detail(length: nil)
    "#{person.full_name}: #{title.presence || Affiliation::FACILITATOR_TITLE} - #{organization.name}"
  end
end
