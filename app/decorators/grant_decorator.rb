class GrantDecorator < ApplicationDecorator
  def amount
    h.number_to_currency(object.amount_dollars)
  end

  def allocated
    h.number_to_currency(object.scholarships_total_cents.to_d / 100)
  end

  def remaining
    h.number_to_currency(object.remaining_dollars)
  end

  def application_deadline
    object.application_deadline&.strftime("%B %-d, %Y") || "—"
  end

  def funds_received_on
    object.funds_received_on&.strftime("%B %-d, %Y") || "—"
  end

  def fully_allocated?
    object.remaining_cents <= 0
  end
end
