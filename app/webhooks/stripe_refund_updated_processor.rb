class StripeRefundUpdatedProcessor
  def call(event)
    stripe_refund = event.data.object
    return unless stripe_refund.object == "refund"
    return unless stripe_refund.status == "canceled"

    refund = Refund.find_by(stripe_refund_id: stripe_refund.id)
    return unless refund

    refund.destroy!

    charge_id = stripe_refund.charge
    return unless charge_id

    external_payment = ExternalProcessorPayment.find_by(stripe_charge_id: charge_id)
    return unless external_payment

    charge = Stripe::Charge.retrieve(
      { id: charge_id, expand: ["refunds", "balance_transaction"] },
      { stripe_account: event.try(:account) }.compact
    )

    external_payment.update!(metadata: (external_payment.metadata || {}).merge(stripe_charge: charge.to_hash))
  end
end
