require "rails_helper"

RSpec.describe EventAttendanceTimeEntryDecorator do
  # The attendance report decorates entries from a service, so the view context Draper
  # has cached is whatever ran last — often a mailer's, which carries ApplicationHelper
  # and nothing else. Pin that here so these labels can't quietly go back to reaching
  # EventAttendanceHelper through `h` and blowing up depending on spec order.
  before { Draper::ViewContext.current = ApplicationMailer.new.view_context }

  let(:entry) do
    build(:event_attendance_time_entry,
      signed_in_at: Time.zone.local(2026, 7, 23, 8, 50),
      signed_out_at: Time.zone.local(2026, 7, 23, 10, 34))
  end

  it "renders the sign-in and sign-out clock times" do
    expect(entry.decorate.signed_in_label).to eq("8:50 AM")
    expect(entry.decorate.signed_out_label).to eq("10:34 AM")
  end

  it "renders the elapsed time" do
    expect(entry.decorate.duration_label).to eq("1h 44m")
  end

  it "marks an entry that's still open" do
    open_entry = build(:event_attendance_time_entry, :open)
    expect(open_entry.decorate.signed_out_label).to eq("—")
    expect(open_entry.decorate.duration_label).to eq("In progress")
  end
end
