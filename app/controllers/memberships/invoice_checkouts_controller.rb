module Memberships
  class InvoiceCheckoutsController < ApplicationController
    def create
      person = current_user.person
      invoice = person&.membership_invoices&.find_by(id: params[:invoice_id])
      authorize! invoice, to: :pay?, with: MembershipInvoicePolicy # needs with policy if membership is nil

      unless invoice.remaining_cost.positive?
        return redirect_to(person_path(person), alert: "This invoice has no balance to pay.", status: :see_other)
      end

      person.set_payment_processor :stripe
      session = balance_checkout_session(person, invoice)
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    private

    def balance_checkout_session(person, invoice)
      metadata = stripe_metadata(membership_id: invoice.membership_id, membership_invoice_id: invoice.id)

      person.payment_processor.checkout(
        mode: "payment",
        metadata: metadata,
        payment_intent_data: { metadata: metadata },
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "AWBW annual membership" },
            unit_amount: invoice.remaining_cost
          },
          quantity: 1
        } ],
        success_url: person_url(person, membership_invoice_checkout: "success"),
        cancel_url: person_url(person, membership_invoice_checkout: "cancelled")
      )
    end
  end
end
