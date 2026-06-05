Rails.application.config.to_prepare do
  Pay::Charge.include PayChargeExtensions
end
