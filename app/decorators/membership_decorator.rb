class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def covered_on?(date = Date.current)
    membership_invoices.any? { |invoice| invoice.active_on?(date) }
  end

  def current_invoice
    membership_invoices.find { |invoice| invoice.active_on?(Date.current) } || membership_invoices.first
  end

  def status_label
    return "Active" unless cancelled?

    "Cancelled #{cancelled_at.strftime("%b %-d, %Y")}"
  end
end
