module Memberships
  class AutopaySetupsController < ApplicationController
    before_action :set_membership

    def create
      authorize! @membership, to: :enable_autopay?

      person = @membership.person
      person.set_payment_processor :stripe

      if person.payment_processor.payment_methods.exists?
        @membership.update!(autopay_on: true)
        return redirect_to person_path(@membership.person),
          notice: "Automatic payments are on.", status: :see_other
      end

      checkout_session = person.payment_processor.checkout(
        mode: "setup",
        currency: Membership::CURRENCY,
        success_url: person_url(@membership.person, autopay_setup: "success"),
        cancel_url: person_url(@membership.person, autopay_setup: "cancelled")
      )
      session[:autopay_setup_membership_id] = @membership.id
      redirect_to checkout_session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to person_path(@membership.person), alert: "Could not reach Stripe: #{e.message}",
        status: :see_other
    end

    private

    def set_membership
      @membership = Membership.find(params[:membership_id])
    end
  end
end
