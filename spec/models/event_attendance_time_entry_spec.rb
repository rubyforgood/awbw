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

  describe "cross-entry guards" do
    let(:registration) { create(:event_registration) }

    def at(hour, min, day: 23)
      Time.zone.local(2026, 7, day, hour, min)
    end

    describe "24-hour daily limit" do
      it "rejects a single entry longer than 24 hours" do
        entry = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(0, 0), signed_out_at: at(1, 0, day: 24))
        expect(entry).not_to be_valid
        expect(entry.errors[:base].join).to match(/24 hours/)
      end

      it "rejects when same-day siblings push the total past 24 hours" do
        create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(0, 0), signed_out_at: at(3, 0)) # 3h on the 23rd
        # 22h more, still the 23rd (attendance date = sign-in day) and adjacent, so no
        # overlap — but 25h total on the day.
        cross = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(3, 0), signed_out_at: at(1, 0, day: 24))
        expect(cross).not_to be_valid
        expect(cross.errors[:base].join).to match(/24 hours/)
      end

      it "allows a day that totals exactly 24 hours" do
        entry = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(0, 0), signed_out_at: at(0, 0, day: 24))
        expect(entry).to be_valid
      end
    end

    describe "same-day overlap" do
      before do
        create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(9, 0), signed_out_at: at(12, 0))
      end

      it "rejects an entry that overlaps an existing session" do
        entry = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(11, 0), signed_out_at: at(13, 0))
        expect(entry).not_to be_valid
        expect(entry.errors[:base].join).to match(/overlaps/)
      end

      it "rejects an entry fully inside an existing session" do
        entry = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(10, 0), signed_out_at: at(11, 0))
        expect(entry).not_to be_valid
      end

      it "rejects an open (not-yet-signed-out) entry inside an existing session" do
        entry = build(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: at(10, 0))
        expect(entry).not_to be_valid
      end

      it "allows a back-to-back entry that only touches at the edge" do
        entry = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(12, 0), signed_out_at: at(13, 0))
        expect(entry).to be_valid
      end

      it "allows the same clock times on a different day" do
        entry = build(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: at(9, 0, day: 24), signed_out_at: at(12, 0, day: 24))
        expect(entry).to be_valid
      end
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
