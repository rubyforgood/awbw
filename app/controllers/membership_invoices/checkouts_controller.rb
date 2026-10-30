module MembershipInvoices
  class CheckoutsController < ApplicationController
    def create
      invoice = MembershipInvoice.find(params[:membership_invoice_id])
      authorize! invoice, to: :pay?
      person = invoice.person

      unless invoice.remaining_cost.positive?
        return redirect_to membership_invoice_path(invoice),
          alert: "This invoice has no balance to pay.", status: :see_other
      end

      result = Membership::InvoiceCheckout.call(
        invoice:,
        success_url: person_url(person, membership_invoice_checkout: "success"),
        cancel_url: cancel_checkout_membership_invoice_url(invoice),
      )
      unless result.success?
        return redirect_to membership_invoice_path(invoice),
          alert: result.errors.to_sentence, status: :see_other
      end

      redirect_to result.session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to membership_invoice_path(invoice),
        alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    def cancel
      invoice = MembershipInvoice.find(params[:id])
      authorize! invoice, to: :pay?

      result = Membership::InvoiceCheckout.cancel(
        invoice:,
        session_id: params[:stripe_checkout_session_id].presence
      )

      if result.success?
        if params[:return_to] == "autopay"
          redirect_to person_path(invoice.person, autopay_setup: "cancelled"), status: :see_other
        else
          redirect_to membership_invoice_path(invoice), notice: "Payment was cancelled.", status: :see_other
        end
      else
        redirect_to membership_invoice_path(invoice),
          alert: result.errors.to_sentence, status: :see_other
      end
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to membership_invoice_path(invoice),
        alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end
  end
end
