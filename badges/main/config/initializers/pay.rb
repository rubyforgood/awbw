Rails.application.config.to_prepare do
  Pay::Charge.include PayChargeExtensions
  Pay.send_emails = false
end
