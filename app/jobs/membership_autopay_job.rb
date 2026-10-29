class MembershipAutopayJob < ApplicationJob
  queue_as :default

  def perform
    return unless Membership.enabled?

    Time.use_zone(Membership::TIME_ZONE) do
      chargeable_invoices.find_each do |invoice|
        process_invoice(invoice)
      end
    end
  end

  private

  def process_invoice(invoice)
    return if invoice.payment_in_progress?
    return if invoice.attempts_exhausted?

    last = invoice.latest_attempt
    return if last&.attempted_at && last.attempted_at.to_date >= Date.current
    return if last&.pending? || last&.unknown? || last&.needs_action?

    card = invoice.person.stripe_customer&.payment_methods&.order(default: :desc, id: :desc)&.first
    if card.blank?
      unless last&.needs_card?
        begin
          invoice.charge_attempts.create!(
            attempt_number: (invoice.charge_attempts.maximum(:attempt_number) || 0) + 1,
            status: "needs_card",
            amount_cents: invoice.remaining_cost,
            attempted_at: Time.current,
            error_code: "no_card",
            error_message: "No card is on file."
          )
        rescue ActiveRecord::RecordNotUnique
        end
      end
      return
    end

    Membership::Autopay::Charge.call(invoice: invoice)
  rescue StandardError => e
    Rails.error.report(
      e,
      handled: true,
      source: "membership.autopay",
      context: { membership_invoice_id: invoice.id }
    )
  end

  def chargeable_invoices
    MembershipInvoice
      .joins(membership: :person)
      .where(memberships: { locked_at: nil, autopay_on: true })
      .merge(MembershipInvoice.not_paid_in_full.autopay_chargeable)
      .includes(membership: :person)
  end
end
