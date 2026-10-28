module MembershipInvoices
  class ChargeAttemptsController < ApplicationController
    def create
      invoice = MembershipInvoice.find(params[:membership_invoice_id])
      authorize! invoice, to: :charge?

      result = Membership::Autopay::Charge.call(invoice:, actor: current_user)
      if result.success?
        redirect_to membership_invoice_path(invoice),
          notice: "Membership charged.", status: :see_other
      else
        redirect_to membership_invoice_path(invoice),
          alert: result.errors.to_sentence, status: :see_other
      end
    end
  end
end
