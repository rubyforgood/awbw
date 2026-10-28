module People
  class AutopaySetupsController < ApplicationController
    before_action :set_person

    def create
      authorize! @person, to: :enable_autopay?

      unless Membership.enabled?
        return redirect_to person_path(@person), alert: "Memberships are not available right now.",
          status: :see_other
      end

      @person.set_payment_processor :stripe

      if @person.payment_processor.payment_methods.exists?
        @person.update!(autopay_on: true)
        return redirect_to person_path(@person),
          notice: "Automatic payments are on.", status: :see_other
      end

      checkout_session = @person.payment_processor.checkout(
        mode: "setup",
        currency: Membership::CURRENCY,
        success_url: person_url(@person, autopay_setup: "success"),
        cancel_url: person_url(@person, autopay_setup: "cancelled")
      )
      session[:autopay_setup_person_id] = @person.id
      redirect_to checkout_session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to person_path(@person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end
  end
end
