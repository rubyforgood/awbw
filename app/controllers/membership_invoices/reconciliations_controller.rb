module MembershipInvoices
  class ReconciliationsController < ApplicationController
    before_action :set_invoice

    def show
      authorize! @invoice, to: :reconcile?
      @lookup = Membership::Reconcile::Lookup.call(invoice: @invoice)
      @reconciliation = MembershipInvoiceReconciliation.new(@invoice)
      @stripe_customer = @invoice.person.stripe_customer
    end

    def create
      authorize! @invoice, to: :reconcile?
      redirect_with(Membership::Reconcile::Action.call(invoice: @invoice, params: params))
    end

    def destroy
      authorize! @invoice, to: :reconcile?
      attempt = @invoice.charge_attempts.find(params[:attempt_id])
      redirect_with(Membership::Reconcile::CancelIntent.call(attempt:))
    end

    private

    def set_invoice
      @invoice = MembershipInvoice
        .includes(:allocations, :invoicee, :bill_to_address, :attention_person,
                  charge_attempts: :pay_charge, membership: :person)
        .find(params[:membership_invoice_id])
    end

    def redirect_with(result)
      if result.success?
        redirect_to reconciliation_path,
          notice: result.message.presence || "Reconciled with Stripe.", status: :see_other
      else
        redirect_alert(result.errors.to_sentence)
      end
    end

    def redirect_alert(message)
      redirect_to reconciliation_path,
        alert: message.presence || "Could not reconcile with Stripe.", status: :see_other
    end

    def reconciliation_path
      options = params[:return_to].present? ? { return_to: params[:return_to] } : {}
      membership_invoice_reconciliation_path(@invoice, **options)
    end
  end
end
