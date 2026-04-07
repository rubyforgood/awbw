ActiveSupport.on_load(:pay) do
  Pay::Webhooks.delegator.subscribe "stripe.checkout.session.completed", FulfillCheckout.new
  Pay::Webhooks.delegator.subscribe "stripe.checkout.session.async_payment_succeeded", FulfillCheckout.new
end
