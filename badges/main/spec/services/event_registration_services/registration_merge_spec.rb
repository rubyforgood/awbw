# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventRegistrationServices::RegistrationMerge do
  let(:event) { create(:event, start_date: 2.days.ago, end_date: 1.day.ago) }
  let(:keep) { create(:event_registration, event: event) }
  let(:delete) { create(:event_registration, event: event) }

  describe "#blocks" do
    it "is empty for two plain registrations" do
      expect(described_class.new(keep, delete).blocks).to be_empty
    end

    it "ignores a checkout the reconcile job already marked unresolved" do
      delete.update!(checkout_session_id: "cs_test_123", payment_unresolved: true)

      expect(described_class.new(keep, delete).blocks).to be_empty
    end

    it "doesn't move the checked time entry onto the keeper" do
      day = event.start_date.in_time_zone.change(hour: 9)
      create(:event_attendance_time_entry, event_registration: keep, signed_in_at: day, signed_out_at: day + 2.hours)
      create(:event_attendance_time_entry, event_registration: delete, signed_in_at: day + 1.hour, signed_out_at: day + 3.hours)

      expect(described_class.new(keep, delete).blocks.sole).to include("overlap")
      expect(keep.reload.event_attendance_time_entries.count).to eq(1)
    end
  end

  describe "#carry_details" do
    it "keeps whichever copy has the attendance days and certificate date" do
      sent_at = 1.hour.ago.change(usec: 0)
      delete.update!(completed_day_2: true, certificate_sent_at: sent_at)

      described_class.new(keep, delete).carry_details

      expect(keep.completed_day_2).to be true
      expect(keep.certificate_sent_at).to eq(sent_at)
    end
  end
end
