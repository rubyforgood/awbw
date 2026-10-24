class ContactMethodDecorator < ApplicationDecorator
  def dedupe_label
    [ kind&.humanize, value ].compact.join(" · ")
  end
end
