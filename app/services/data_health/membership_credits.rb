module DataHealth
  class MembershipCredits < Check
    def title = "Membership credits and overpayments"

    def explanation
      "Portal-originated membership payments with money left after their invoice was paid, " \
      "or with no linked invoice. Apply or refund them, or acknowledge the credit on the " \
      "payment to hide it from Data health."
    end

    def scope
      return ExternalProcessorPayment.none unless Membership.enabled?

      ids = candidates.select { |payment| MembershipPaymentLink.new(payment).credit? }.map(&:id)
      ExternalProcessorPayment.where(id: ids).includes(:person, :organization, :pay_charge)
    end

    def describe(payment)
      link = MembershipPaymentLink.new(payment)
      invoice_label =
        if link.invoice
          "#{link.invoice.start_date.strftime('%b %-d, %Y')} invoice paid"
        else
          "linked invoice missing"
        end
      "#{payer_name(payment)} - #{MoneyFormatter.dollars_from_cents(payment.amount_cents_remaining)} " \
        "credit - #{invoice_label}"
    end

    def path_for(payment) = payment_path(payment)

    private

    def candidates
      @candidates ||= ExternalProcessorPayment.membership_originated
        .where(amount_cents_remaining: 1.., reconciliation_acknowledged_at: nil)
        .to_a
    end

    def payer_name(payment)
      payer = payment.payer
      return "Unknown payer" if payer.blank?

      payer.respond_to?(:full_name) ? payer.full_name : payer.name
    end
  end
end
