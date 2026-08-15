require "rails_helper"

RSpec.describe EventAttendanceReport do
  # A two-day training, 9:00am–4:00pm each day.
  let(:event) do
    create(:event, ce_hours_offered: 6,
      start_date: Time.zone.local(2026, 7, 23, 9, 0),
      end_date: Time.zone.local(2026, 7, 24, 16, 0),
      registration_close_date: Time.zone.local(2026, 7, 20, 9, 0))
  end

  def registration_for(first, last)
    create(:event_registration, event: event, registrant: create(:person, first_name: first, last_name: last))
  end

  def make_ce(registration, number:, hours: 6)
    license = create(:professional_license, person: registration.registrant, number: number)
    create(:continuing_education_registration, event_registration: registration, professional_license: license, hours: hours)
  end

  def entry(registration, in_at, out_at)
    create(:event_attendance_time_entry, event_registration: registration, signed_in_at: in_at, signed_out_at: out_at)
  end

  describe "#dates" do
    it "is each event day" do
      expect(described_class.new(event).dates).to eq([ Date.new(2026, 7, 23), Date.new(2026, 7, 24) ])
    end
  end

  describe "#dates_truncated?" do
    it "is false when the event fits within the 5-day date cap" do
      expect(described_class.new(event).dates_truncated?).to be(false)
    end

    it "is true when the event runs past the capped dates" do
      long_event = create(:event, ce_hours_offered: 6,
        start_date: Time.zone.local(2026, 7, 20, 9, 0),
        end_date: Time.zone.local(2026, 7, 27, 16, 0),
        registration_close_date: Time.zone.local(2026, 7, 15, 9, 0))
      expect(described_class.new(long_event).dates_truncated?).to be(true)
    end
  end

  describe "CE report (ce_only: true)" do
    let!(:alice) { registration_for("Alice", "Adams") }
    let!(:bob)   { registration_for("Bob", "Baker") }
    let!(:carol) { registration_for("Carol", "Cole") }

    before do
      make_ce(alice, number: "AAA111")
      make_ce(bob, number: "BBB222")
      # Carol is not a CE registrant — excluded from the CE report.
      entry(alice, Time.zone.local(2026, 7, 23, 8, 50), Time.zone.local(2026, 7, 23, 10, 34)) # 104m
      entry(alice, Time.zone.local(2026, 7, 23, 10, 44), Time.zone.local(2026, 7, 23, 12, 8)) # 84m
      entry(alice, Time.zone.local(2026, 7, 24, 9, 0), Time.zone.local(2026, 7, 24, 16, 0))   # 420m
      entry(carol, Time.zone.local(2026, 7, 23, 9, 0), Time.zone.local(2026, 7, 23, 10, 0))
    end

    subject(:report) { described_class.new(event, ce_only: true) }

    def row_for(registration)
      report.rows.find { |row| row.registration == registration }
    end

    it "lists a line per CE registrant sorted by name, even with no entries yet" do
      expect(report.rows.map(&:registration)).to eq([ alice, bob ])
      expect(report.rows.map(&:name)).to eq([ "Alice Adams", "Bob Baker" ])
    end

    it "groups a line's entries by day in sign-in order" do
      day1 = report.entries_for(row_for(alice), Date.new(2026, 7, 23))
      expect(day1.map(&:signed_in_label)).to eq([ "8:50 AM", "10:44 AM" ])
    end

    it "totals minutes per day and overall" do
      expect(report.day_minutes(row_for(alice), Date.new(2026, 7, 23))).to eq(188)
      expect(report.day_minutes(row_for(alice), Date.new(2026, 7, 24))).to eq(420)
      expect(report.total_minutes(row_for(alice))).to eq(608)
      expect(report.total_minutes(row_for(bob))).to eq(0)
      expect(report.grand_total_minutes).to eq(608)
    end

    it "surfaces the line's own license number and awarded hours" do
      expect(row_for(alice).license_number).to eq("AAA111")
      expect(row_for(alice).hours_awarded).to eq(6)
    end

    it "totals minutes per day and hours awarded across all lines" do
      expect(report.day_grand_minutes(Date.new(2026, 7, 23))).to eq(188)
      expect(report.day_grand_minutes(Date.new(2026, 7, 24))).to eq(420)
      expect(report.total_hours_awarded).to eq(12) # Alice 6 + Bob 6
    end

    it "excludes time logged outside the event's days from a line's total" do
      # 8 hours on a date the training doesn't run — must not inflate the total.
      create(:event_attendance_time_entry, event_registration: alice,
        signed_in_at: Time.zone.local(2026, 8, 1, 9, 0), signed_out_at: Time.zone.local(2026, 8, 1, 17, 0))
      expect(report.total_minutes(row_for(alice))).to eq(608) # still just Jul 23 (188) + Jul 24 (420)
    end

    it "flags a line with an open (not signed out) entry" do
      create(:event_attendance_time_entry, :open, event_registration: bob)
      expect(report.open?(row_for(bob))).to be(true)
      expect(report.open?(row_for(alice))).to be(false)
    end

    # Nobody chases a cancelled registrant for sign-ins, and their awarded hours
    # aren't part of what the training certified — same active-only scoping the
    # roster and onboarding tabs use.
    it "leaves out registrations that are no longer active" do
      dana = create(:event_registration, event: event, status: "cancelled",
        registrant: create(:person, first_name: "Dana", last_name: "Dean"))
      make_ce(dana, number: "DDD444")

      expect(report.rows.map(&:registration)).not_to include(dana)
      expect(report.total_hours_awarded).to eq(12) # Alice 6 + Bob 6, not Dana's too
    end

    # Two licences means two boards, audited separately: each is shown only its own
    # licence and its own awarded hours, over the one set of times the registrant
    # actually logged.
    context "when a registrant claims CE against two licences" do
      before { make_ce(bob, number: "AAA999", hours: 3) }

      it "reports a line per licence, each keyed separately" do
        bob_rows = report.rows.select { |row| row.registration == bob }
        expect(bob_rows.map(&:license_number)).to eq([ "AAA999", "BBB222" ])
        expect(bob_rows.map(&:hours_awarded)).to eq([ 3, 6 ])
        expect(bob_rows.map(&:key).uniq.size).to eq(2)
      end

      it "sums hours awarded across the lines — each board awards its own" do
        expect(report.total_hours_awarded).to eq(15) # Alice 6 + Bob 6 + 3
      end

      # The lines share one set of times, so counting both would bank Bob's hours twice.
      it "counts each person's logged time once in the everyone-totals" do
        entry(bob, Time.zone.local(2026, 7, 23, 9, 0), Time.zone.local(2026, 7, 23, 10, 0)) # 60m

        expect(report.day_grand_minutes(Date.new(2026, 7, 23))).to eq(248) # 188 + 60, not 188 + 120
        expect(report.grand_total_minutes).to eq(668)
      end

      # The day heading's "N of M signed in" counts people for the same reason.
      it "counts each person present on a day once" do
        entry(bob, Time.zone.local(2026, 7, 23, 9, 0), Time.zone.local(2026, 7, 23, 10, 0))

        expect(report.registrations_present_on(Date.new(2026, 7, 23))).to eq(2) # Alice + Bob, not 3 lines
        expect(report.reported_registrations.size).to eq(2)
      end
    end
  end

  describe "generic report (ce_only: false)" do
    let!(:alice) { registration_for("Alice", "Adams") }
    let!(:carol) { registration_for("Carol", "Cole") }

    before do
      registration_for("Bob", "Baker") # no entries → excluded
      entry(alice, Time.zone.local(2026, 7, 23, 8, 50), Time.zone.local(2026, 7, 23, 10, 34))
      entry(carol, Time.zone.local(2026, 7, 23, 9, 0), Time.zone.local(2026, 7, 23, 10, 0))
    end

    it "lists only registrations that logged time, one line each" do
      rows = described_class.new(event).rows
      expect(rows.map(&:registration)).to eq([ alice, carol ])
      expect(rows.map(&:ce_registration)).to all(be_nil)
      # Keyed by registration alone, so the generic report's cell ids are unchanged.
      expect(rows.first.key).to eq(alice.id.to_s)
    end

    it "leaves out an inactive registration even when it logged time" do
      dana = create(:event_registration, event: event, status: "no_show",
        registrant: create(:person, first_name: "Dana", last_name: "Dean"))
      entry(dana, Time.zone.local(2026, 7, 23, 9, 0), Time.zone.local(2026, 7, 23, 10, 0))

      expect(described_class.new(event).rows.map(&:registration)).to eq([ alice, carol ])
    end
  end
end
