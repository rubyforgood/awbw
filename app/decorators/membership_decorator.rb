class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def coverage_label
    active? ? "Membership good through:" : "Membership ended:"
  end

  def status_label
    return "Ending #{end_date.strftime("%b %-d, %Y")}" if active? && autorenewal_cancelled?
    return "Active" if active?

    ended? ? "Ended" : "Lapsed"
  end

  def status_classes
    return "bg-orange-50 text-orange-700 border-orange-200" if !active? && owes?
    return "bg-gray-50 text-gray-600 border-gray-200" unless active?
    return "bg-amber-50 text-amber-700 border-amber-200" if autorenewal_cancelled?

    "bg-green-50 text-green-700 border-green-200"
  end

  def auto_renewal_label
    return "Auto-renew: enabled" if active? && !autorenewal_cancelled?
    return "Auto-renew: cancelled on #{autorenewal_cancelled_at.strftime("%b %-d, %Y")}" if active?
    return "Auto-renew: on — renews if the outstanding invoice is paid" if owes? && !autorenewal_cancelled?

    "Auto-renew: off"
  end

  def period_label
    return if start_date.blank? || end_date.blank?

    end_str = end_date >= Date.current ? "present" : end_date.strftime("%b %-d, %Y")
    "#{start_date.strftime("%b %-d, %Y")} – #{end_str}"
  end

  def stripe_active? = person.payment_processor&.subscribed?
end
