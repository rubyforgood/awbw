class MembershipInvoiceReconciliation
  include ActionView::Helpers::DateHelper

  Issue = Data.define(:kind, :label, :detail) do
    def to_s = [ label, detail ].compact_blank.join(": ")
  end

  attr_reader :invoice, :issues

  def initialize(invoice)
    @invoice = invoice
    @issues = build_issues
  end

  def needed? = issues.any?

  def summary = issues.map(&:to_s).to_sentence

  def invoice_label
    "#{invoice.start_date.strftime('%b %-d, %Y')} – #{invoice.end_date.strftime('%b %-d, %Y')}"
  end

  def path(return_to: nil)
    params = return_to.present? ? { return_to: } : {}
    helpers.membership_invoice_reconciliation_path(invoice, **params)
  end

  private

  def helpers = Rails.application.routes.url_helpers

  def build_issues
    items = []
    if unresolved_attempts.any?
      items << Issue.new(
        kind: :unresolved_attempt,
        label: "#{unresolved_attempts.size} unresolved #{'attempt'.pluralize(unresolved_attempts.size)}",
        detail: attempt_detail
      )
    end
    if stale_checkout?
      items << Issue.new(kind: :stale_checkout, label: "checkout session", detail: "never resolved")
    end
    if unallocated_payments.any?
      total = unallocated_payments.sum(&:amount_cents_remaining)
      items << Issue.new(
        kind: :unallocated_payment,
        label: "unallocated payment",
        detail: MoneyFormatter.dollars_from_cents(total)
      )
    end
    items
  end

  def unresolved_attempts
    @unresolved_attempts ||= invoice.charge_attempts.select(&:unresolved?)
  end

  def stale_checkout?
    invoice.checkout_session_id.present? && !invoice.payment_in_progress?
  end

  def unallocated_payments
    return [] if invoice.paid_in_full?

    @unallocated_payments ||= ExternalProcessorPayment.membership_originated
      .where(amount_cents_remaining: 1.., reconciliation_acknowledged_at: nil)
      .select { |payment| MembershipPaymentLink.new(payment).invoice == invoice }
  end

  def attempt_detail
    latest = unresolved_attempts.max_by(&:attempted_at)
    return if latest.nil?

    age = latest.attempted_at ? "#{time_ago_in_words(latest.attempted_at)} ago" : nil
    [ latest.status.humanize, age ].compact_blank.join(", ")
  end
end
