# Formats an invoice view timestamp in the viewer's time zone, so both invoice
# surfaces render opens identically.
class InvoiceViewedLabel
  FORMAT = "%b %-d, %Y at %-l:%M %p".freeze

  def self.for(time)
    time&.in_time_zone&.strftime(FORMAT)
  end
end
