class MembershipCheckoutsController < ApplicationController
  def create
    authorize! :membership_checkout, to: :create?

    person = current_user.person
    membership = person.memberships.not_cancelled.first || person.memberships.create!
    invoice = Membership::EnsureInvoice.call(membership: membership)

    person.set_payment_processor :stripe
    redirect_to checkout_session(person, membership, invoice).url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
  end

  private

  def checkout_session(person, membership, invoice)
    metadata = { membership_id: membership.id }

    person.payment_processor.checkout(
      mode: "subscription",
      metadata: metadata,
      subscription_data: { metadata: metadata, trial_end: first_charge_on(invoice) }.compact,
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

  # Only defer the first charge when the current invoice is already paid for, so Stripe's
  # billing period lines up with the invoice chain instead of double-charging it. Pinned to
  # the membership zone so the date can't shift with the member's own.
  def first_charge_on(invoice)
    return unless invoice&.paid_in_full?

    Time.use_zone(Membership::TIME_ZONE) { (invoice.end_date + 1.day).beginning_of_day.to_i }
  end
end
