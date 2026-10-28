module People
  class BillingPortalsController < ApplicationController
    before_action :set_person

    def create
      authorize! @person, to: :manage_payment_methods?

      @person.set_payment_processor :stripe
      session = @person.payment_processor.billing_portal(
        return_url: request.referer.presence || person_url(@person)
      )
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to person_path(@person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end
  end
end
