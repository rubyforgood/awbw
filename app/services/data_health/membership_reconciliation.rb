module DataHealth
  # Memberships whose invoices have a payment that hasn't been checked against
  # Stripe: an unresolved automatic attempt, or a checkout session whose window
  # has passed without resolving. The fix is per invoice, with Stripe.
  class MembershipReconciliation < Check
    def title = "Memberships with payments to reconcile"

    def explanation
      "Invoices with an unresolved automatic payment attempt or a checkout session that never " \
      "finished. Open the membership, then the invoice, to check Stripe and apply or release the payment."
    end

    def scope
      return Membership.none unless Membership.enabled?

      Membership
        .where(id: MembershipInvoice.where(id: unresolved_invoice_ids).select(:membership_id))
        .or(Membership.where(id: MembershipInvoice.where(id: stale_checkout_invoice_ids).select(:membership_id)))
        .includes(:person, membership_invoices: [ :charge_attempts, :allocations ])
    end

    def describe(membership)
      "#{membership.person&.full_name || 'Unknown person'} — #{issue_summary(membership)}"
    end

    def path_for(membership) = membership_path(membership)

    private

    def unresolved_invoice_ids
      MembershipChargeAttempt.unresolved.select(:membership_invoice_id)
    end

    def stale_checkout_invoice_ids
      MembershipInvoice
        .where.not(checkout_session_id: nil)
        .where("payment_in_progress_at IS NULL OR payment_in_progress_at <= ?", MembershipInvoice::PAYMENT_WINDOW.ago)
        .select(:id)
    end

    def issue_summary(membership)
      invoices = membership.membership_invoices.select do |invoice|
        invoice.charge_attempts.any?(&:unresolved?) || invoice.checkout_session_id.present?
      end

      attempts = invoices.sum { |invoice| invoice.charge_attempts.count(&:unresolved?) }
      sessions = invoices.count { |invoice| invoice.checkout_session_id.present? }
      parts = []
      parts << "#{attempts} unresolved #{'attempt'.pluralize(attempts)}" if attempts.positive?
      parts << "#{sessions} checkout #{'session'.pluralize(sessions)}" if sessions.positive?
      parts.join(", ")
    end
  end
end
