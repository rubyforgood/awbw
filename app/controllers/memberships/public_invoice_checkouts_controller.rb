module Memberships
  class PublicInvoiceCheckoutsController < ApplicationController
    include SearchEngineHideable

    skip_before_action :authenticate_user!
    before_action :noindex!
    before_action :set_membership_invoice

    def show
      authorize! @membership_invoice, to: :show_public?
      flash.now[:notice] = "Thank you! Your payment was received." if params[:paid].present?
      flash.now[:alert] = "Payment was cancelled." if params[:cancelled].present?
      @invoice = MembershipInvoicePresenter.new(@membership_invoice)
    end

    def create
      authorize! @membership_invoice, to: :show_public?

      unless @membership_invoice.remaining_cost.positive?
        return redirect_to memberships_public_invoice_checkout_path(params[:token]),
          notice: "This invoice has already been paid.", status: :see_other
      end

      session = Membership::InvoiceCheckout.call(
        invoice: @membership_invoice,
        success_url: memberships_public_invoice_checkout_url(params[:token], paid: "1"),
        cancel_url: memberships_public_invoice_checkout_url(params[:token], cancelled: "1")
      )
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      redirect_to memberships_public_invoice_checkout_path(params[:token]),
        alert: "Could not reach Stripe: #{e.message}", status: :see_other
    end

    private

    def set_membership_invoice
      @membership_invoice = MembershipInvoice.find_signed(
        params[:token], purpose: MembershipInvoice::PAYMENT_TOKEN_PURPOSE
      )
      raise ActiveRecord::RecordNotFound if @membership_invoice.nil?
    end
  end
end
