require "rails_helper"

RSpec.describe EventPaymentRemindersJob, type: :job do
  # A paid event whose ticket payment deadline lands a given number of days from
  # today (negative = in the past), at noon so it sits inside that whole day.
  def event_due_in(days)
    create(:event, cost_cents: 135_000, payment_due_deadline: (Time.zone.today + days).to_time.change(hour: 12))
  end

  # Only the payment-reminder kinds this job sends — other notifications (e.g. a
  # cancellation email) may exist on the registration independently.
  def kinds_for(registration)
    Notification.where(noticeable: registration, kind: EventPaymentRemindersJob::PHASE_KINDS.values).pluck(:kind)
  end

  around { |example| travel_to(Time.zone.local(2026, 4, 1, 9, 0)) { example.run } }

  describe "#perform" do
    it "sends the week reminder for a balance due a week before the deadline" do
      registration = create(:event_registration, event: event_due_in(7))

      expect { described_class.new.perform }.to change { kinds_for(registration) }
        .to([ "event_payment_reminder_week" ])
    end

    it "sends the day reminder for a balance due the day before the deadline" do
      registration = create(:event_registration, event: event_due_in(1))

      described_class.new.perform

      expect(kinds_for(registration)).to eq([ "event_payment_reminder_day" ])
    end

    it "sends the overdue reminder once the deadline has passed" do
      registration = create(:event_registration, event: event_due_in(-1))

      described_class.new.perform

      expect(kinds_for(registration)).to eq([ "event_payment_reminder_overdue" ])
    end

    it "does not send outside any reminder window" do
      registration = create(:event_registration, event: event_due_in(3))

      described_class.new.perform

      expect(kinds_for(registration)).to be_empty
    end

    it "does not resend the same phase on a second run" do
      registration = create(:event_registration, event: event_due_in(7))
      described_class.new.perform

      expect { described_class.new.perform }.not_to change(Notification, :count)
      expect(kinds_for(registration)).to eq([ "event_payment_reminder_week" ])
    end

    it "skips a registration paid in full" do
      event = event_due_in(7)
      registration = create(:event_registration, event:)
      create(:allocation, source: create(:payment), allocatable: registration, amount: event.cost_cents)

      described_class.new.perform

      expect(kinds_for(registration)).to be_empty
    end

    it "skips a cancelled registration" do
      registration = create(:event_registration, event: event_due_in(7), status: "cancelled")

      described_class.new.perform

      expect(kinds_for(registration)).to be_empty
    end

    it "still reminds a registration someone else is paying for (intention unknown)" do
      registration = create(:event_registration, event: event_due_in(7), someone_else_will_pay: true)

      described_class.new.perform

      expect(kinds_for(registration)).to eq([ "event_payment_reminder_week" ])
    end

    it "skips a free event" do
      event = create(:event, cost_cents: 0, payment_due_deadline: (Time.zone.today + 7).to_time.change(hour: 12))
      registration = create(:event_registration, event:)

      described_class.new.perform

      expect(kinds_for(registration)).to be_empty
    end

    it "ignores an overdue deadline beyond the lookback window" do
      registration = create(:event_registration, event: event_due_in(-(EventPaymentRemindersJob::OVERDUE_LOOKBACK.in_days.to_i + 5)))

      described_class.new.perform

      expect(kinds_for(registration)).to be_empty
    end

    it "sends each registration on the same event its own reminder" do
      event = event_due_in(1)
      3.times { create(:event_registration, event:) }

      expect { described_class.new.perform }
        .to change { Notification.where(kind: "event_payment_reminder_day").count }.by(3)
    end
  end
end
