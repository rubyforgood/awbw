require "rails_helper"

RSpec.describe ContinuingEducationRegistrationDecorator do
  let(:event) { create(:event, :ended, ce_hours_offered: 6) }
  let(:registration) { create(:event_registration, event: event, status: "attended") }
  let(:ce_registration) { create(:continuing_education_registration, event_registration: registration, hours: 6, cost_cents: 0) }

  describe "#certificate_locked_reason" do
    it "is nil once the certificate is earned" do
      expect(ce_registration.decorate.certificate_locked_reason).to be_nil
    end

    it "names the unmet condition" do
      registration.update!(status: "registered")

      expect(ce_registration.decorate.certificate_locked_reason).to eq("Unlocks once your attendance is confirmed")
    end

    it "joins several unmet conditions" do
      registration.update!(status: "registered")
      ce_registration.update!(cost_cents: 15_000)

      expect(ce_registration.decorate.certificate_locked_reason)
        .to eq("Unlocks once your attendance is confirmed and your CE payment is received in full")
    end

    it "names short signed-in time when attendance time was logged" do
      create(:event_attendance_time_entry, event_registration: registration,
                                           signed_in_at: event.end_date - 1.hour, signed_out_at: event.end_date)

      expect(ce_registration.decorate.certificate_locked_reason).to eq("Unlocks once your signed-in time covers the CE hours")
    end
  end

  describe "#certificate_conditions" do
    it "leaves off the signed-in time condition when no time was logged" do
      labels = ce_registration.decorate.certificate_conditions.map(&:label)

      expect(labels).not_to include("your signed-in time covers the CE hours")
    end
  end
end
