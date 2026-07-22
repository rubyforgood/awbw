# The "Pay for Others" submitters who belong on an event's bulk-reminder page:
# those whose submission still has an attendee not connected to a registration,
# or a matched registration that isn't paid in full. Reuses the same fuzzy
# attendee-to-registration matching the bulk-payments dashboard uses
# (FormSubmissionDecorator#matched_attendees), so "connected" means the same
# thing on both pages. Fully-resolved submissions (everyone registered and paid)
# are left out — there's nothing to remind the payer about.
class BulkPaymentReminderRecipients
  # One qualifying submitter plus the counts that explain why they're here.
  Recipient = Data.define(:submission, :email, :attendee_count, :unregistered_count, :unpaid_count) do
    def payer_name
      submission.bulk_payment_payer_name
    end

    def outstanding_count
      unregistered_count + unpaid_count
    end
  end

  def initialize(event)
    @event = event
  end

  def call
    submissions.filter_map { |submission| recipient_for(submission) }
  end

  private

  def submissions
    @event.form_submissions
      .bulk_payment
      .includes(:person, form_answers: :form_field)
      .order(created_at: :desc)
  end

  # Every active registration on the event — matched in memory against each
  # submission's attendees. Loaded once (with registrant + allocations) so the
  # per-submission matching and paid-in-full checks cost no extra queries.
  def registrations
    @registrations ||= @event.event_registrations
      .active
      .includes(registrant: :contact_methods, allocations: [])
      .to_a
  end

  def recipient_for(submission)
    email = submission.bulk_payment_reminder_email
    return if email.blank?

    matched = submission.decorate.matched_attendees(registrations)
    unregistered = matched.count { |attendee| attendee[:matches].empty? }
    # Matched, but the registration we linked them to still owes money. An
    # attendee tied to several registrations counts as paid once any is settled.
    unpaid = matched.count { |attendee| attendee[:matches].present? && attendee[:matches].none?(&:paid_in_full?) }
    return if unregistered.zero? && unpaid.zero?

    Recipient.new(
      submission: submission,
      email: email,
      attendee_count: matched.size,
      unregistered_count: unregistered,
      unpaid_count: unpaid
    )
  end
end
