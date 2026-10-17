class Membership::BillingPortalsController < ApplicationController
  def create
    person = current_user.person
    membership = person&.current_membership
    authorize! membership, to: :billing_portal?, with: MembershipPolicy

    return redirect_to(person_path(person), alert: "No active autopay subscription.", status: :see_other) unless person.pay_subscriptions.active.exists?

    person.set_payment_processor :stripe
    session = person.payment_processor.billing_portal(return_url: person_url(person))
    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
  end
end
