class DuesSubscriptionDecorator < ApplicationDecorator
  def rate_label
    return "Standard (#{h.dollars_from_cents(Dues::ANNUAL_COST_CENTS)})" if rate_cents.nil?

    "Locked at #{h.dollars_from_cents(rate_cents)}"
  end

  def status_label
    return "Active" unless cancelled?

    "Cancelled #{cancelled_at.strftime("%b %-d, %Y")}"
  end
end
