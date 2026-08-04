require "rails_helper"

RSpec.describe EventAttendanceTimeEntry, type: :model do
  describe "validations" do
    it "requires a sign-in time" do
      entry = build(:event_attendance_time_entry, signed_in_at: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:signed_in_at]).to be_present
    end

    it "is valid while still open (no sign-out yet)" do
      expect(build(:event_attendance_time_entry, :open)).to be_valid
    end

    it "rejects a sign-out at or before the sign-in" do
      at = Time.current
      expect(build(:event_attendance_time_entry, signed_in_at: at, signed_out_at: at)).not_to be_valid
      expect(build(:event_attendance_time_entry, signed_in_at: at, signed_out_at: at - 1.minute)).not_to be_valid
    end
  end

  describe "#open?" do
    it "is true only without a sign-out time" do
      expect(build(:event_attendance_time_entry, :open)).to be_open
      expect(build(:event_attendance_time_entry)).not_to be_open
    end
  end

  describe "#duration_minutes" do
    it "returns whole minutes between sign-in and sign-out" do
      entry = build(:event_attendance_time_entry,
        signed_in_at: Time.zone.local(2026, 7, 23, 8, 50),
        signed_out_at: Time.zone.local(2026, 7, 23, 10, 34))
      expect(entry.duration_minutes).to eq(104)
    end

    it "rounds to the nearest minute" do
      entry = build(:event_attendance_time_entry,
        signed_in_at: Time.zone.local(2026, 7, 23, 8, 50, 0),
        signed_out_at: Time.zone.local(2026, 7, 23, 8, 51, 40))
      expect(entry.duration_minutes).to eq(2)
    end

    it "is nil while open" do
      expect(build(:event_attendance_time_entry, :open).duration_minutes).to be_nil
    end
  end

  describe "#attendance_date" do
    it "is the sign-in's calendar date in the app zone" do
      entry = build(:event_attendance_time_entry, signed_in_at: Time.zone.local(2026, 7, 23, 8, 50))
      expect(entry.attendance_date).to eq(Date.new(2026, 7, 23))
    end
  end

  describe "scopes" do
    it "separates open from closed entries" do
      reg = create(:event_registration)
      open_entry = create(:event_attendance_time_entry, :open, event_registration: reg)
      closed_entry = create(:event_attendance_time_entry, event_registration: reg)

      expect(reg.event_attendance_time_entries.open).to contain_exactly(open_entry)
      expect(reg.event_attendance_time_entries.closed).to contain_exactly(closed_entry)
    end
  end
end
