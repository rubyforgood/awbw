class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def status_label
    return "Active" unless cancelled?

    "Cancelled #{cancelled_at.strftime("%b %-d, %Y")}"
  end
end
