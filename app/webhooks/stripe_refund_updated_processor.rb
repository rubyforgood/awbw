class StripeRefundUpdatedProcessor
  def call(event)
    stripe_refund = event.data.object
    return unless stripe_refund.object == "refund"
    return unless stripe_refund.status == "canceled"

    refund = Refund.find_by(stripe_refund_id: stripe_refund.id)
    refund&.destroy!
  end
end
