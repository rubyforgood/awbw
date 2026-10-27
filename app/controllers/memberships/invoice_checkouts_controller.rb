module Memberships
  class InvoiceCheckoutsController < ApplicationController
    def create
      person = current_user.person
      invoice = person&.membership_invoices&.find_by(id: params[:invoice_id])
      authorize! invoice, to: :pay?, with: MembershipInvoicePolicy # needs `with:` policy if membership is nil

      unless invoice.remaining_cost.positive?
        return redirect_to(person_path(person), alert: "This invoice has no balance to pay.", status: :see_other)
      end

      session = Membership::InvoiceCheckout.call(
        invoice: invoice,
        success_url: person_url(person, membership_invoice_checkout: "success"),
        cancel_url: person_url(person, membership_invoice_checkout: "cancelled")
      )
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      redirect_to person_path(person), alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end
  end
end
