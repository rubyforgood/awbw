Rails.application.config.to_prepare do
  Pay::Charge.include PayChargeExtensions

  ActiveSupport.on_load(:pay) do
    Pay::Webhooks.delegator.subscribe(
      "stripe.charge.succeeded",
      StripeChargeSucceededProcessor.new
    )
    Pay::Webhooks.delegator.subscribe(
      "stripe.charge.refunded",
      StripeChargeRefundedProcessor.new
    )
    Pay::Webhooks.delegator.subscribe(
      "stripe.charge.refund.updated",
      StripeRefundUpdatedProcessor.new
    )
  end

  Pay.send_emails = false
end
