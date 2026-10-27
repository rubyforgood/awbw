module Memberships
  class SubscriptionCheckoutsController < ApplicationController
    def create
      person = current_user.person
      membership = person&.current_membership
      authorize! membership, to: :set_up_subscription?, with: MembershipPolicy # needs `with:` policy if membership is nil

      if membership.owes?
        return redirect_to(person_path(person), alert: "Please pay the current balance first.", status: :see_other)
      end

      if membership.next_billing_cents.to_i.zero?
        return redirect_to(person_path(person),
          alert: "Your next year is already covered. Automatic renewal can be set up once it ends.",
          status: :see_other)
      end

      unless membership.autopay_window_open?
        return redirect_to(person_path(person),
          alert: "Automatic renewal can be set up closer to your renewal date.", status: :see_other)
      end

      person.set_payment_processor :stripe

      if membership.stripe_subscription&.active?
        return redirect_to(person_path(person), alert: "Automatic renewal is already set up for this membership.", status: :see_other)
      end

      start = membership.next_billing_start_date
      Membership::EnsureInvoice.call(membership: membership) if start.blank?
      session = subscription_checkout_session(person, membership, start)
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    private

    def subscription_checkout_session(person, membership, start)
      metadata = stripe_metadata(membership_id: membership.id)
      anchor = billing_cycle_anchor(start)

      person.payment_processor.checkout(
        mode: "subscription",
        metadata: metadata,
        subscription_data: { metadata: metadata, billing_cycle_anchor: anchor }.compact
          .merge(anchor ? { proration_behavior: "none" } : {}),
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "AWBW annual membership" },
            unit_amount: membership.next_billing_cents,
            recurring: { interval: "year" }
          },
          quantity: 1
        } ],
        success_url: person_url(person, membership_subscription_checkout: "success"),
        cancel_url: person_url(person, membership_subscription_checkout: "cancelled")
      )
    end

    def billing_cycle_anchor(start)
      return if start.blank? || start <= Date.current

      anchor = Time.use_zone(Membership::TIME_ZONE) { start.beginning_of_day }
      anchor = 1.hour.from_now if anchor < 1.hour.from_now
      anchor.to_i
    end
  end
end
