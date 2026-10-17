module Memberships
  class SubscriptionCheckoutsController < ApplicationController
    def create
      person = current_user.person
      membership = person&.current_membership
      authorize! membership, to: :checkout?, with: MembershipPolicy

      if membership.owes?
        return redirect_to(person_path(person), alert: "Please pay the current balance first.", status: :see_other)
      end

      person.set_payment_processor :stripe
      invoice = Membership::EnsureInvoice.call(membership: membership)
      session = subscription_checkout_session(person, membership, invoice)
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    private

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
        success_url: person_url(person, membership_subscription_checkout: "success"),
        cancel_url: person_url(person, membership_subscription_checkout: "cancelled")
      )
    end

    def billing_cycle_anchor(invoice)
      return if invoice.blank?
      return if invoice.start_date >= Date.current && !invoice.paid_in_full?

      Time.use_zone(Membership::TIME_ZONE) { (invoice.end_date + 1.day).beginning_of_day.to_i }
    end
  end
end
