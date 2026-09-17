class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def status_label
    return "Active" unless cancelled?

    "Cancelled #{cancelled_at.strftime("%b %-d, %Y")}"
  end

  def period_label
    starts = membership_invoices.filter_map(&:start_date).sort
    ends = membership_invoices.filter_map(&:end_date).sort
    return if starts.empty?

    start_str = starts.first.strftime("%b %-d, %Y")
    if ends.empty? || ends.last >= Date.current
      "#{start_str} – present"
    else
      "#{start_str} – #{ends.last.strftime("%b %-d, %Y")}"
    end
  end
end
