module DataHealth
  class MembershipReconciliation < Check
    def title = "Membership invoices with payments to reconcile"

    def explanation
      "Invoices with an unresolved automatic payment attempt or a checkout session that never " \
      "finished. Open one to check Stripe and apply or release the payment."
    end

    def scope
      return MembershipInvoice.none unless Membership.enabled?

      MembershipInvoice.needing_reconciliation
        .includes(:allocations, charge_attempts: :pay_charge, membership: :person)
    end

    def describe(invoice)
      summary = MembershipInvoiceReconciliation.new(invoice)
      "#{invoice.person.full_name} - #{summary.invoice_label} - #{summary.summary}"
    end

    def path_for(invoice)
      MembershipInvoiceReconciliation.new(invoice).path(return_to: "data_health")
    end
  end
end
