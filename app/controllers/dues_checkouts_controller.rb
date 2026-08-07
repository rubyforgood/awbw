class DuesCheckoutsController < ApplicationController
  def create
    authorize! :dues_checkout, to: :create?

    person = current_user.person
    subscription = person.dues_subscriptions.not_cancelled.first || person.dues_subscriptions.create!
    term = Dues::EnsureTerm.call(dues_subscription: subscription)

    person.set_payment_processor :stripe
    redirect_to checkout_session(person, subscription, term).url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
  end

  private

  def checkout_session(person, subscription, term)
    metadata = { dues_subscription_id: subscription.id }

    person.payment_processor.checkout(
      mode: "subscription",
      metadata: metadata,
      subscription_data: { metadata: metadata, trial_end: first_charge_on(term) }.compact,
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: { name: "AWBW annual dues" },
          unit_amount: subscription.cost_cents || Dues::ANNUAL_COST_CENTS,
          recurring: { interval: "year" }
        },
        quantity: 1
      } ],
      success_url: person_url(person, dues_checkout: "success"),
      cancel_url: person_url(person, dues_checkout: "cancelled")
    )
  end

  # Only defer the first charge when the current term is already paid for, so Stripe's
  # billing period lines up with the term chain instead of double-charging it. Pinned to
  # the dues zone so the date can't shift with the member's own.
  def first_charge_on(term)
    return unless term&.paid_in_full?

    Time.use_zone(Dues::TIME_ZONE) { (term.end_date + 1.day).beginning_of_day.to_i }
  end
end
