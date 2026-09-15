class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def status_label
    return "Active" unless cancelled?

    "Cancelled #{cancelled_at.strftime("%b %-d, %Y")}"
  end

  # The membership's covered span: earliest invoice start to latest invoice end.
  # Nil when no invoice has dates yet.
  def period_label
    starts = membership_invoices.filter_map(&:start_date)
    ends = membership_invoices.filter_map(&:end_date)
    return if starts.empty? || ends.empty?

    "#{starts.min.strftime("%b %-d, %Y")} – #{ends.max.strftime("%b %-d, %Y")}"
  end
end
