class RefundDecorator < ApplicationDecorator
  def page_title_label
    payee = recipient.is_a?(Person) ? h.person_name(recipient) : recipient.try(:name)
    [ "Refund", h.dollars_from_cents(amount_cents), payee ].compact_blank.join(" · ")
  end
end
