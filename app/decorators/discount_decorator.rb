class DiscountDecorator < ApplicationDecorator
  def page_title_label
    [ "Discount", h.dollars_from_cents(amount_cents), event&.decorate&.compact_label ].compact_blank.join(" · ")
  end
end
