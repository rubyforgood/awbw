class MembershipCheckoutsController < ApplicationController
  def create
    authorize! :membership_checkout, to: :create?

    person = current_user.person
    membership = person.memberships.autorenewal_not_cancelled.first || person.memberships.create!
    invoice = Membership::EnsureInvoice.call(membership: membership)

    person.set_payment_processor :stripe
    session = if grace_balance?(invoice)
      balance_checkout_session(person, membership, invoice)
    else
      subscription_checkout_session(person, membership, invoice)
    end

    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
  end

  private

  # A started-but-unpaid year is debited one-time; a year starting today (or one
  # already paid) goes straight to the subscription session. After the payment
  # lands the member can click "Set up" again from their profile — the invoice
  # will now be paid, triggering the subscription path with the billing anchor.
  def grace_balance?(invoice)
    invoice&.outstanding_started?
  end

  def balance_checkout_session(person, membership, invoice)
    metadata = stripe_metadata(membership_id: membership.id)

    person.payment_processor.checkout(
      mode: "payment",
      metadata: metadata,
      payment_intent_data: { metadata: metadata },
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: { name: "AWBW annual membership" },
          unit_amount: invoice.remaining_cost
        },
        quantity: 1
      } ],
      success_url: person_url(person, membership_checkout: "success"),
      cancel_url: person_url(person, membership_checkout: "cancelled")
    )
  end

  def subscription_checkout_session(person, membership, invoice)
    metadata = stripe_metadata(membership_id: membership.id)
    anchor = billing_cycle_anchor(invoice)

    person.payment_processor.checkout(
      mode: "subscription",
      metadata: metadata,
      subscription_data: { metadata: metadata, billing_cycle_anchor: anchor }.compact
        .merge(anchor ? { proration_behavior: "none" } : {}),
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: { name: "AWBW annual membership" },
          unit_amount: membership.cost_cents || Membership::ANNUAL_COST_CENTS,
          recurring: { interval: "year" }
        },
        quantity: 1
      } ],
      success_url: person_url(person, membership_checkout: "success"),
      cancel_url: person_url(person, membership_checkout: "cancelled")
    )
  end

  def billing_cycle_anchor(invoice)
    return if invoice.blank?
    return if invoice.start_date >= Date.current && !invoice.paid_in_full?

    Time.use_zone(Membership::TIME_ZONE) { (invoice.end_date + 1.day).beginning_of_day.to_i }
  end
end
