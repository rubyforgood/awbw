class ProfessionalLicenseDecorator < ApplicationDecorator
  Badge = Struct.new(:label, :icon, :classes, keyword_init: true)

  # Expiry pill: expired / expiring soon / valid, or unknown when no date is on file.
  def expiry_badge
    return Badge.new(label: "No expiry on file", icon: "fa-regular fa-circle-question", classes: "bg-gray-50 text-gray-500 border-gray-200") if expires_on.blank?
    return Badge.new(label: "Expired", icon: "fa-solid fa-circle-xmark", classes: "bg-red-50 text-red-700 border-red-200") if expired?
    if expires_on <= 60.days.from_now.to_date
      return Badge.new(label: "Expiring soon", icon: "fa-solid fa-triangle-exclamation", classes: "bg-amber-50 text-amber-700 border-amber-200")
    end
    Badge.new(label: "Valid", icon: "fa-solid fa-circle-check", classes: "bg-green-50 text-green-700 border-green-200")
  end

  # CE hours issued against this license this calendar year — only registrations
  # whose certificate has been sent (in the current year) count.
  def ce_hours_issued_this_year
    issued_ce_hours { |registration| registration.certificate_sent_at.year == Date.current.year }
  end

  # CE hours issued against this license across all years.
  def ce_hours_issued_all_years
    issued_ce_hours
  end

  private

  # Sum CE hours from registrations whose certificate has been sent, optionally
  # narrowed by the given block. Whole totals drop the decimal.
  def issued_ce_hours
    issued = continuing_education_registrations.select { |registration| registration.certificate_sent_at.present? }
    issued = issued.select { |registration| yield(registration) } if block_given?
    total = issued.sum { |registration| registration.hours || 0 }
    total == total.to_i ? total.to_i : total
  end
end
