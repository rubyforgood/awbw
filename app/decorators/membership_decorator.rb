class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership::ANNUAL_COST_CENTS)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def status_label
    return autorenewal_cancelled? ? "Ended" : "Lapsed" unless active?
    return "Ends #{end_date.strftime("%b %-d, %Y")}" if autorenewal_cancelled?

    "Active"
  end

  def status_classes
    return "bg-gray-50 text-gray-600 border-gray-200" if !active? && autorenewal_cancelled?
    return "bg-orange-50 text-orange-700 border-orange-200" unless active?
    return "bg-amber-50 text-amber-700 border-amber-200" if autorenewal_cancelled?

    "bg-green-50 text-green-700 border-green-200"
  end

  def auto_renewal_label
    return "Auto-renew: enabled" if !autorenewal_cancelled? && active?
    return "Auto-renew: on — renews if the outstanding invoice is paid" if !autorenewal_cancelled?
    return "Auto-renew: cancelled on #{autorenewal_cancelled_at.strftime("%b %-d, %Y")}" if active?

    "Auto-renew: off"
  end

  def period_label
    return if start_date.blank? || end_date.blank?

    end_str = end_date >= Date.current ? "present" : end_date.strftime("%b %-d, %Y")
    "#{start_date.strftime("%b %-d, %Y")} – #{end_str}"
  end

  def stripe_active? = person.payment_processor&.subscribed?
end
