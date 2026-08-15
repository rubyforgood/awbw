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
end
