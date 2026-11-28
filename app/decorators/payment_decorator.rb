class PaymentDecorator < ApplicationDecorator
  def page_title_label
    payer = person ? h.person_name(person) : organization&.name
    [ object.model_name.human, h.dollars_from_cents(amount_cents), payer ].compact_blank.join(" · ")
  end
end
