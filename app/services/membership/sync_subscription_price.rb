class Membership::SyncSubscriptionPrice
  def self.call(membership:) = new(membership:).call

  def initialize(membership:)
    @membership = membership
  end

  # Bring the Stripe subscription's price in line with the next year's invoice, without
  # prorating the year in progress. A comped year cancels the subscription instead,
  # since a $0 charge would have nothing to allocate to.
  def call
    return unless Membership.enabled?

    subscription = @membership.stripe_subscription
    return if subscription.blank? || subscription.canceled?
    return unless subscription.active? || subscription.past_due?

    target = @membership.next_billing_cents.to_i
    return cancel(subscription) if target.zero?

    item = stripe_item(subscription)
    return if item.price.unit_amount == target

    updated = Stripe::Subscription.update(
      subscription.processor_id,
      {
        items: [ { id: item.id, price_data: price_data(item, target) } ],
        proration_behavior: "none",
        expand: [ "items.data.price" ]
      },
      { stripe_account: subscription.stripe_account }.compact
    )
    Pay::Stripe::Subscription.sync(subscription.processor_id, object: updated)
  rescue Stripe::StripeError, Pay::Error => e
    Rails.logger.warn("[Membership] Could not sync the Stripe price for membership #{@membership.id}: #{e.message}")
  end

  private

  def stripe_item(subscription)
    @stripe_item ||= Stripe::Subscription.retrieve(
      { id: subscription.processor_id, expand: [ "items.data.price" ] },
      { stripe_account: subscription.stripe_account }.compact
    ).items.data.first
  end

  # Stripe prices are immutable, so each amount change adds one on the same product.
  def price_data(item, target)
    {
      currency: item.price.currency,
      product: item.price.product,
      unit_amount: target,
      recurring: {
        interval: item.price.recurring.interval,
        interval_count: item.price.recurring.interval_count
      }
    }
  end

  def cancel(subscription)
    subscription.cancel_now!
  rescue Stripe::StripeError, Pay::Error => e
    Rails.logger.warn("[Membership] Could not cancel the Stripe subscription for membership #{@membership.id}: #{e.message}")
  end
end
