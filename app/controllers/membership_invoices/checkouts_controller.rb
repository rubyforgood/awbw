module MembershipInvoices
  class CheckoutsController < ApplicationController
    def create
      invoice = MembershipInvoice.find(params[:membership_invoice_id])
      authorize! invoice, to: :pay?, with: MembershipInvoicePolicy
      person = invoice.person

      unless invoice.remaining_cost.positive?
        return redirect_to membership_invoice_path(invoice),
          alert: "This invoice has no balance to pay.", status: :see_other
      end

      session = Membership::InvoiceCheckout.call(
        invoice:,
        success_url: person_url(person, membership_invoice_checkout: "success"),
        cancel_url: person_url(person, membership_invoice_checkout: "cancelled"),
      )
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError, Pay::Error => e
      redirect_to membership_invoice_path(invoice),
        alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end
  end
end
