module MembershipInvoices
  class SubscribeCheckoutsController < ApplicationController
    def create
      invoice = MembershipInvoice.find(params[:id])
      authorize! invoice.membership, to: :enable_autopay?

      unless invoice.remaining_cost.positive?
        return redirect_to membership_invoice_path(invoice),
          alert: "This invoice has no balance to pay.", status: :see_other
      end

      result = Membership::InvoiceCheckout.call(
        invoice:,
        success_url: person_url(invoice.person, membership_invoice_checkout: "success", autopay: "1"),
        cancel_url: cancel_checkout_membership_invoice_url(invoice),
        save_card: true
      )

      unless result.success?
        return redirect_to membership_invoice_path(invoice),
          alert: result.errors.to_sentence, status: :see_other
      end

      session[:autopay_setup_membership_id] = invoice.membership_id
      redirect_to result.session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to membership_invoice_path(invoice),
        alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end
  end
end
