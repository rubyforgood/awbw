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

    it "lists every CE registrant sorted by name, even with no entries yet" do
      expect(report.registrations).to eq([ alice, bob ])
    end

    it "groups a registrant's entries by day in sign-in order" do
      day1 = report.entries_for(alice, Date.new(2026, 7, 23))
      expect(day1.map(&:signed_in_label)).to eq([ "8:50 AM", "10:44 AM" ])
    end

    it "totals minutes per day and overall" do
      expect(report.day_minutes(alice, Date.new(2026, 7, 23))).to eq(188)
      expect(report.day_minutes(alice, Date.new(2026, 7, 24))).to eq(420)
      expect(report.total_minutes(alice)).to eq(608)
      expect(report.total_minutes(bob)).to eq(0)
      expect(report.grand_total_minutes).to eq(608)
    end

    it "surfaces license numbers and awarded hours" do
      expect(report.license_numbers(alice)).to eq([ "AAA111" ])
      expect(report.ce_hours(alice)).to eq(6)
    end

    it "flags a registrant with an open (not signed out) entry" do
      create(:event_attendance_time_entry, :open, event_registration: bob)
      expect(report.open?(bob)).to be(true)
      expect(report.open?(alice)).to be(false)
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

    it "lists only registrations that logged time" do
      expect(described_class.new(event).registrations).to eq([ alice, carol ])
    end
  end
end
