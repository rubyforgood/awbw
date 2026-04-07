# app/webhooks/fulfill_checkout.rb

class FulfillCheckout
  def call(event)
    object = event.data.object
    return if object.payment_status != "paid"

    person = Person.find(object.metadata["person_id"])
    return unless person

    ExternalProcessorPayment.create!(
         payer: person,
         amount_cents: object.amount_total,
      amount_cents_remaining: object.amount_total,
         currency: object.currency,
         pay_charge_id: Pay::Charge.last.id
       )
  end
end
