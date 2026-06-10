Rails.application.config.to_prepare do
  Pay::Charge.include PayChargeExtensions

  ActiveSupport.on_load(:pay) do
    Pay::Webhooks.delegator.subscribe(
      "stripe.charge.succeeded",
      StripeChargeSucceededProcessor.new
    )
  end
end
