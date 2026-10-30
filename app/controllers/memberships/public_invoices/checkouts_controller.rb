module Memberships
  module PublicInvoices
    class CheckoutsController < ApplicationController
      include SearchEngineHideable

      skip_before_action :authenticate_user!
      before_action :noindex!
      before_action :set_membership_invoice

      def create
        authorize! @membership_invoice, to: :show_public?

        unless @membership_invoice.remaining_cost.positive?
          return redirect_to memberships_public_invoice_path(token),
            notice: "This invoice has already been paid.", status: :see_other
        end

        result = Membership::InvoiceCheckout.call(
          invoice: @membership_invoice,
          success_url: memberships_public_invoice_url(token, paid: "1"),
          cancel_url: cancel_checkout_memberships_public_invoice_url(token)
        )
        unless result.success?
          return redirect_to memberships_public_invoice_path(token),
            alert: result.errors.to_sentence, status: :see_other
        end

        redirect_to result.session.url, allow_other_host: true, status: :see_other
      rescue Stripe::StripeError, Pay::Error => e
        redirect_to memberships_public_invoice_path(token),
          alert: "Could not reach Stripe: #{e.message}", status: :see_other
      end

      def cancel
        authorize! @membership_invoice, to: :show_public?

        result = Membership::InvoiceCheckout.cancel(
          invoice: @membership_invoice,
          session_id: params[:stripe_checkout_session_id].presence
        )

        if result.success?
          redirect_to memberships_public_invoice_path(token), notice: "Payment was cancelled.", status: :see_other
        else
          redirect_to memberships_public_invoice_path(token),
            alert: result.errors.to_sentence, status: :see_other
        end
      rescue Stripe::StripeError, Pay::Error => e
        redirect_to memberships_public_invoice_path(token),
          alert: "Could not reach Stripe: #{e.message}", status: :see_other
      end

      private

      def token = params[:token]

      def set_membership_invoice
        @membership_invoice = MembershipInvoice.find_signed(
          token, purpose: MembershipInvoice::PAYMENT_TOKEN_PURPOSE
        )
        raise ActiveRecord::RecordNotFound if @membership_invoice.nil?
      end
    end
  end
end
