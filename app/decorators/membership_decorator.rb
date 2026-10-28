class MembershipDecorator < ApplicationDecorator
  def cost_label
    return "Standard (#{h.dollars_from_cents(Membership.annual_cost_cents)})" if cost_cents.nil?

    "Locked at #{h.dollars_from_cents(cost_cents)}"
  end

  def coverage_label
    return "Membership starts:" if upcoming?

    active? ? "Membership good through:" : "Membership ended:"
  end

  def coverage_date
    upcoming? ? start_date : end_date
  end

  def status_label
    return "Upcoming" if upcoming?
    return "Ending #{end_date.strftime("%b %-d, %Y")}" if active? && autorenewal_cancelled?
    return "Active" if active?

    "Ended"
  end

  def status_classes
    return "bg-blue-50 text-blue-700 border-blue-200" if upcoming?
    return "bg-amber-50 text-amber-700 border-amber-200" if active? && autorenewal_cancelled?
    return "bg-green-50 text-green-700 border-green-200" if active?

    "bg-gray-50 text-gray-600 border-gray-200"
  end

  def payment_label
    return "Upcoming" if upcoming?
    return "Balance due" if owes?

    "Paid"
  end

  def payment_classes
    return "bg-blue-50 text-blue-700 border-blue-200" if upcoming?
    return "bg-amber-50 text-amber-700 border-amber-200" if owes?

    "bg-green-50 text-green-700 border-green-200"
  end

  def autopay_label(has_card:)
    return "On" if person&.autopay_on? && has_card
    return "Needs card" if person&.autopay_on?

    "Off"
  end

  def autopay_classes(has_card:)
    return "bg-green-50 text-green-700 border-green-200" if person&.autopay_on? && has_card
    return "bg-amber-50 text-amber-700 border-amber-200" if person&.autopay_on?

    "bg-gray-50 text-gray-600 border-gray-200"
  end

  def auto_renewal_label
    renewal_on? ? "on" : "off"
  end

  def period_label
    return if start_date.blank? || end_date.blank?

    "#{start_date.strftime('%b %-d, %Y')} – #{end_date.strftime('%b %-d, %Y')}"
  end
end
