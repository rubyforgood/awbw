# Daily scan (see config/recurring.yml) that emails registrants with an
# outstanding ticket balance as their event's payment deadline approaches and
# once after it passes: a week before, the day before, and one overdue notice.
# Each send flows through NotificationServices::CreateNotification, so it is
# logged in the person's communication history and deduped by notification kind
# (a registration is only ever sent one reminder per phase).
class EventPaymentRemindersJob < ApplicationJob
  queue_as :default

  # How far back past a deadline the one-time overdue reminder still fires, so a
  # first deploy (or a stalled cron) never blasts long-past deadlines.
  OVERDUE_LOOKBACK = 30.days

  # phase => notification kind. Order is only cosmetic; each phase dedupes on its
  # own kind, so a registration can receive all three over time.
  PHASE_KINDS = {
    week: "event_payment_reminder_week",
    day: "event_payment_reminder_day",
    overdue: "event_payment_reminder_overdue"
  }.freeze

  def perform
    PHASE_KINDS.each do |phase, kind|
      registrations_for(phase).each do |registration|
        next if reminder_sent?(registration, kind)
        send_reminder(registration, kind)
      end
    end
  end

  private

  # Active, not-paid-in-full registrations on the paid events whose deadline puts
  # them in this phase's window. Buddy-payment registrants (someone_else_will_pay)
  # are included for now — until we can confirm their payer's intention, an unpaid
  # balance still warrants a reminder.
  def registrations_for(phase)
    EventRegistration
      .active
      .not_paid_in_full
      .where(event_id: events_for(phase))
      .includes(:registrant, :event)
  end

  def events_for(phase)
    today = Time.zone.today
    case phase
    when :week then Event.payment_due_on(today + 7.days)
    when :day then Event.payment_due_on(today + 1.day)
    when :overdue
      Event.payment_due_between((today - OVERDUE_LOOKBACK).beginning_of_day, today.beginning_of_day)
    end
  end

  def reminder_sent?(registration, kind)
    Notification.exists?(noticeable: registration, kind: kind)
  end

  def send_reminder(registration, kind)
    NotificationServices::CreateNotification.call(
      noticeable: registration,
      kind: kind,
      recipient_role: :person,
      recipient_email: registration.registrant.preferred_email,
      notification_type: 0
    )
  end
end
