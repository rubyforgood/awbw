class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def coverage_label
    active? ? "Membership good through:" : "Membership ended:"
  end

  def status_label
    return "Upcoming" if upcoming?
    return "Ending #{end_date.strftime("%b %-d, %Y")}" if active? && autorenewal_cancelled?
    return "Active" if active? || renewal_in_flight?

    ended? ? "Ended" : "Lapsed"
  end

  def status_classes
    return "bg-blue-50 text-blue-700 border-blue-200" if upcoming?
    return "bg-amber-50 text-amber-700 border-amber-200" if active? && autorenewal_cancelled?
    return "bg-green-50 text-green-700 border-green-200" if active? || renewal_in_flight?
    return "bg-orange-50 text-orange-700 border-orange-200" if owes?

    "bg-gray-50 text-gray-600 border-gray-200"
  end

  def auto_renewal_label
    return "enabled" if active? && !autorenewal_cancelled?
    return "cancelled on #{autorenewal_cancelled_at.strftime("%b %-d, %Y")}" if active?
    return "on — renews if the outstanding invoice is paid" if owes? && !autorenewal_cancelled?

    "off"
  end

  def period_label
    return if start_date.blank? || end_date.blank?

    end_str = end_date >= Date.current ? "present" : end_date.strftime("%b %-d, %Y")
    "#{start_date.strftime("%b %-d, %Y")} – #{end_str}"
  end

  def stripe_active? = person.payment_processor&.subscribed?
end
