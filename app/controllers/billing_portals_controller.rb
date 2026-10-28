class BillingPortalsController < ApplicationController
  def create
    person = current_user.person

    unless person
      skip_verify_authorized!
      return redirect_to(root_path, alert: "No profile found.", status: :see_other)
    end

    authorize! person, to: :manage_payment_methods?, with: PersonPolicy

    person.set_payment_processor :stripe
    session = person.payment_processor.billing_portal(
      return_url: request.referer.presence || person_url(person)
    )
    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError, Pay::Error => e
    redirect_to person_url(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
  end
end
