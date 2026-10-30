module Memberships
  class PublicInvoicesController < ApplicationController
    include AhoyTracking
    include SearchEngineHideable

    skip_before_action :authenticate_user!
    before_action :noindex!
    before_action :set_membership_invoice

    def show
      authorize! @membership_invoice, to: :show_public?
      @token = params[:token]
      @payment_received = params[:paid].present?
      flash.now[:notice] = "Thank you! Your payment was received." if @payment_received
      flash.now[:alert] = "Payment was cancelled." if params[:cancelled].present?
      @invoice = MembershipInvoicePresenter.new(@membership_invoice)
      track_view("invoices", { membership_invoice_id: @membership_invoice.id, via: "public_link" })
    end

    private

    def set_membership_invoice
      @membership_invoice = MembershipInvoice.find_signed(
        params[:token], purpose: MembershipInvoice::PAYMENT_TOKEN_PURPOSE
      )
      raise ActiveRecord::RecordNotFound if @membership_invoice.nil?

      @membership_invoice.allocations.load
      @membership_invoice.charge_attempts.load
    end
  end
end
