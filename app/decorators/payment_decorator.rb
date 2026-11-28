class PaymentDecorator < ApplicationDecorator
  def page_title_label
    payer_name = payer.is_a?(Person) ? h.person_name(payer) : payer&.name
    [ object.model_name.human, h.dollars_from_cents(amount_cents), payer_name ].compact_blank.join(" · ")
  end
end
