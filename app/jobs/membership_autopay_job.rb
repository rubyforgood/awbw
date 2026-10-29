class MembershipAutopayJob < ApplicationJob
  queue_as :default

  def perform
    return unless Membership.enabled?

    Time.use_zone(Membership::TIME_ZONE) do
      chargeable_invoices.find_each do |invoice|
        next if invoice.payment_in_progress?
        next if invoice.attempts_exhausted?

        last = invoice.latest_attempt
        if last&.attempted_at.present? && last.attempted_at.to_date >= Date.current &&
           !last.needs_card? && !last.failed?
          next
        end
        next if last&.pending? || last&.unknown? || last&.needs_action?

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
          next
        end

        Membership::Autopay::Charge.call(invoice: invoice)
      end
    end
  end

  private

  def chargeable_invoices
    start_dates = (Date.current - MembershipChargeAttempt::RETRY_WINDOW_DAYS)..
      (Date.current + Membership.renewal_window_days)

    MembershipInvoice
      .joins(membership: :person)
      .where(memberships: { locked_at: nil, autopay_on: true })
      .merge(MembershipInvoice.not_paid_in_full)
      .where(start_date: start_dates)
      .includes(membership: :person)
  end
end
