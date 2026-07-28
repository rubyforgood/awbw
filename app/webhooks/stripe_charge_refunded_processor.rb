class StripeChargeRefundedProcessor
  def call(event)
    stripe_charge = event.data.object
    return unless stripe_charge.amount_refunded > 0

    external_payment = Payment.find_by(stripe_charge_id: stripe_charge.id)
    return unless external_payment

    charge = Stripe::Charge.retrieve(
      { id: stripe_charge.id, expand: [ "refunds" ] },
      { stripe_account: event.try(:account) }.compact
    )

    (charge.refunds&.data || []).each do |stripe_refund|
      next unless stripe_refund.status == "succeeded"
      next if Refund.exists?(stripe_refund_id: stripe_refund.id)

      Refund.create!(
        refundable: external_payment,
        recipient: external_payment.payer,
        amount_cents: stripe_refund.amount,
        method: "stripe",
        stripe_refund_id: stripe_refund.id
      )
    end

    external_payment.update!(metadata: (external_payment.metadata || {}).merge(stripe_charge: charge.to_hash))
  end
end
