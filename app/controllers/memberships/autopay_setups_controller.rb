module Memberships
  class AutopaySetupsController < ApplicationController
    before_action :set_membership

    def create
      authorize! @membership, to: :enable_autopay?

      person = @membership.person
      processor = person.stripe_payment_processor

      if processor.payment_methods.exists?
        enable_autopay!
        return redirect_to person_path(person),
          notice: "Automatic payments are on.", status: :see_other
      end

      invoice = @membership.next_autopay_invoice
      if invoice
        if invoice.payment_in_progress?
          return redirect_to person_path(person),
            alert: "A payment is already in progress for this invoice. Finish or cancel it first.",
            status: :see_other
        end

        result = Membership::InvoiceCheckout.call(
          invoice:,
          success_url: person_url(person, membership_invoice_checkout: "success", autopay: "1"),
          cancel_url: cancel_checkout_membership_invoice_url(invoice, return_to: "autopay"),
          save_card: true
        )
        unless result.success?
          return redirect_to person_path(person),
            alert: result.errors.to_sentence, status: :see_other
        end

        session[:autopay_setup_membership_id] = @membership.id
        return redirect_to result.session.url, allow_other_host: true, status: :see_other
      end

      checkout_session = processor.checkout(
        mode: "setup",
        currency: Membership::CURRENCY,
        success_url: person_url(person, autopay_setup: "success"),
        cancel_url: person_url(person, autopay_setup: "cancelled")
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

    def enable_autopay!
      @membership.update!(autopay_on: true)
      MembershipAutopayJob.perform_later
    end
  end
end
