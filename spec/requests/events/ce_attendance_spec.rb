require "rails_helper"

# Registrant self-service CE sign-in/out from the public CE callout (slug is the
# authorization, no login). The paper CE hour sign-in sheet, moved into the portal.
RSpec.describe "Events::Callouts CE attendance", type: :request do
  # A one-day training running 9:00am–4:00pm; "now" is mid-morning, inside the window.
  let(:event) do
    create(:event,
      ce_hours_offered: 6, ce_hours_cost_cents: 15_000,
      start_date: Time.zone.local(2026, 7, 23, 9, 0),
      end_date: Time.zone.local(2026, 7, 23, 16, 0),
      registration_close_date: Time.zone.local(2026, 7, 20, 9, 0))
  end
  let(:registration) { create(:event_registration, event: event) }

  before { travel_to Time.zone.local(2026, 7, 23, 10, 0) }
  after { travel_back }

  # A CE registration paid in full — the gate for the whole attendance surface.
  def pay_ce!
    license = create(:professional_license, person: registration.registrant, number: "LIC123")
    ce = create(:continuing_education_registration, event_registration: registration, professional_license: license)
    create(:allocation, source: create(:payment), allocatable: ce, amount: ce.cost_cents)
    registration.reload
  end

  describe "POST /registration/:slug/ce/sign-in" do
    it "records an open entry and redirects with a notice while CE is paid and in-window" do
      pay_ce!
      expect {
        post registration_ce_sign_in_path(registration.slug)
      }.to change { registration.event_attendance_time_entries.count }.by(1)

      entry = registration.event_attendance_time_entries.last
      expect(entry).to be_open
      expect(entry.signed_in_at).to eq(Time.current)
      expect(entry.created_by).to be_nil # public self-service isn't attributed
      expect(response).to redirect_to(registration_ce_path(registration.slug, anchor: "attendance"))
      expect(flash[:notice]).to include("Signed in")
    end

    it "does nothing when CE isn't paid in full" do
      expect {
        post registration_ce_sign_in_path(registration.slug)
      }.not_to change { registration.event_attendance_time_entries.count }
      expect(flash[:alert]).to be_present
    end

    it "does nothing outside the day's sign-in window" do
      pay_ce!
      travel_to Time.zone.local(2026, 7, 23, 6, 0)
      expect {
        post registration_ce_sign_in_path(registration.slug)
      }.not_to change { registration.event_attendance_time_entries.count }
      expect(flash[:alert]).to include("training day")
    end

    it "doesn't open a second entry while already signed in" do
      pay_ce!
      create(:event_attendance_time_entry, :open, event_registration: registration)
      expect {
        post registration_ce_sign_in_path(registration.slug)
      }.not_to change { registration.event_attendance_time_entries.count }
    end
  end

  describe "POST /registration/:slug/ce/sign-out" do
    it "closes the open entry" do
      pay_ce!
      entry = create(:event_attendance_time_entry, :open, event_registration: registration,
        signed_in_at: Time.current - 1.hour)

      post registration_ce_sign_out_path(registration.slug)

      expect(entry.reload.signed_out_at).to eq(Time.current)
      expect(response).to redirect_to(registration_ce_path(registration.slug, anchor: "attendance"))
      expect(flash[:notice]).to include("Signed out")
    end

    it "reports when there's nothing to sign out of" do
      pay_ce!
      post registration_ce_sign_out_path(registration.slug)
      expect(flash[:alert]).to be_present
    end
  end

  # A sign-out someone forgot on day one must not carry into day two: it would block
  # the new day's sign-in, and closing it at "now" would bank a ~24-hour session
  # against day one. Day two starts fresh, and the open day gets its own catch-up
  # button stamped with that day's scheduled end.
  describe "an entry left open on an earlier day" do
    let(:event) do
      create(:event,
        ce_hours_offered: 6, ce_hours_cost_cents: 15_000,
        start_date: Time.zone.local(2026, 7, 23, 9, 0),
        end_date: Time.zone.local(2026, 7, 24, 16, 0),
        registration_close_date: Time.zone.local(2026, 7, 20, 9, 0))
    end
    let!(:stale) do
      create(:event_attendance_time_entry, :open, event_registration: registration,
        signed_in_at: Time.zone.local(2026, 7, 23, 9, 0))
    end

    before do
      pay_ce!
      travel_to Time.zone.local(2026, 7, 24, 10, 0)
    end

    it "starts day two signed out, offering Sign in for today" do
      get registration_ce_path(registration.slug)
      expect(response.body).to include(registration_ce_sign_in_path(registration.slug))
    end

    it "lets the registrant sign in for the new day" do
      expect {
        post registration_ce_sign_in_path(registration.slug)
      }.to change { registration.event_attendance_time_entries.count }.by(1)
    end

    it "prompts to close day one, naming the day and the time it will record" do
      get registration_ce_path(registration.slug)
      expect(response.body).to include("You never signed out on")
      expect(response.body).to include("Thursday, July 23")
      expect(response.body).to include("Sign out for Jul 23")
      # The 16:00 UTC end of that training day, rendered in the page's Pacific zone.
      expect(response.body).to include("Signing out records 9:00 AM, when that day's training ended.")
      expect(response.body).to include(registration_ce_sign_out_path(registration.slug, entry_id: stale.id))
    end

    it "closes day one at that day's scheduled end, not now" do
      post registration_ce_sign_out_path(registration.slug, params: { entry_id: stale.id })

      expect(stale.reload.signed_out_at).to eq(Time.zone.local(2026, 7, 23, 16, 0))
      expect(flash[:notice]).to include("Signed out for Thu, Jul 23")
    end

    it "leaves the stale entry alone when today's Sign out is used instead" do
      post registration_ce_sign_out_path(registration.slug)
      expect(stale.reload.signed_out_at).to be_nil
      expect(flash[:alert]).to be_present
    end

    it "ignores an entry_id that isn't the registrant's open earlier day" do
      other = create(:event_attendance_time_entry, :open, event_registration: create(:event_registration),
        signed_in_at: Time.zone.local(2026, 7, 23, 9, 0))

      post registration_ce_sign_out_path(registration.slug, params: { entry_id: other.id })

      expect(other.reload.signed_out_at).to be_nil
      expect(stale.reload.signed_out_at).to be_nil
      expect(flash[:alert]).to be_present
    end

    # Nothing sensible to stamp when the sign-in is after the day was already over,
    # so the one-click close isn't offered and staff correct it on the report.
    it "doesn't offer the catch-up close for a sign-in after that day ended" do
      stale.update_columns(signed_in_at: Time.zone.local(2026, 7, 23, 20, 0))

      get registration_ce_path(registration.slug)
      expect(response.body).not_to include("You never signed out on")
    end
  end

  describe "GET /registration/:slug/ce (attendance section)" do
    it "shows a Sign in button once CE is paid and the window is open" do
      pay_ce!
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Training sign-in")
      expect(response.body).to include("Sign in")
    end

    it "omits the Signed out chip until something has been logged today" do
      pay_ce!
      get registration_ce_path(registration.slug)
      expect(response.body).not_to include("Signed out")
    end

    it "shows the Signed out chip and a Sign in again button after signing out today" do
      pay_ce!
      create(:event_attendance_time_entry, event_registration: registration,
        signed_in_at: Time.current - 2.hours, signed_out_at: Time.current - 1.hour)
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Signed out")
      expect(response.body).to include("Sign in again")
    end

    it "styles Sign out as the primary CTA while signed in" do
      pay_ce!
      create(:event_attendance_time_entry, :open, event_registration: registration,
        signed_in_at: Time.current - 30.minutes)
      get registration_ce_path(registration.slug)
      expect(response.body).to match(/<button[^>]*bg-teal-600[^>]*>Sign out</)
    end

    it "shows a Sign out button and today's entries while signed in" do
      pay_ce!
      create(:event_attendance_time_entry, :open, event_registration: registration,
        signed_in_at: Time.zone.local(2026, 7, 23, 9, 30))
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Sign out")
      expect(response.body).to include("Signed in at")
      # The day table labels its clock times with the page's zone (Pacific).
      expect(response.body).to include("Your times (PDT)")
      expect(response.body).to include("2:30 AM–— · In progress")
    end

    it "shows the event dates and daily times on their own header line" do
      pay_ce!
      get registration_ce_path(registration.slug)
      # The event runs 9:00–16:00 UTC; the public page renders in Pacific (2–9 am).
      expect(response.body).to include("Jul 23, 2026 · 2 - 9 am PDT")
    end

    it "shows the opening time and the event-start note before the window" do
      pay_ce!
      travel_to Time.zone.local(2026, 7, 23, 6, 30)
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Sign-in opens")
      # 8:30/9:00 UTC (open/start) shown in the page's Pacific zone.
      expect(response.body).to include("1:30 AM PDT")
      expect(response.body).to include("Event begins 30 min later, at 2:00 AM PDT.")
      expect(response.body).not_to include("in about 2 hours")
    end

    it "shows staff an admin chip linking to the event's attendance report" do
      pay_ce!
      sign_in create(:user, :admin)
      get registration_ce_path(registration.slug)
      expect(response.body).to include(attendance_event_path(event, ce: "true"))
    end

    it "hides the attendance report chip from registrants" do
      pay_ce!
      get registration_ce_path(registration.slug)
      expect(response.body).not_to include(attendance_event_path(event, ce: "true"))
    end

    # The buttons are done once the training is, but the day table isn't: filling in
    # a day afterwards is exactly what someone who forgot to tap Sign in needs.
    it "keeps the day table editable once the training is over, without the buttons" do
      pay_ce!
      travel_to Time.zone.local(2026, 7, 30, 10, 0)
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Training sign-in")
      expect(response.body).not_to include("Sign-in opens")
      expect(response.body).not_to include(registration_ce_sign_in_path(registration.slug))
      expect(response.body).to include(
        registration_ce_path(registration.slug, edit: "2026-07-23", anchor: "attendance")
      )
    end

    it "hides the attendance section until CE is paid in full" do
      license = create(:professional_license, person: registration.registrant, number: "LIC123")
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      get registration_ce_path(registration.slug)
      expect(response.body).not_to include("Training sign-in")
    end

    it "shows the section on the admin sample-ticket preview, with the controls inert" do
      sign_in create(:user, :admin)
      get sample_ce_event_path(event)

      expect(response.body).to include("Training sign-in")
      expect(response.body).to match(/<button[^>]*disabled[^>]*>Sign in</)
      expect(response.body).not_to include(registration_ce_sign_in_path("sample"))
    end
  end

  # The buttons only stamp "now". Someone who arrived before signing in, forgot to tap
  # them, or is writing the whole training up afterwards edits their own times here
  # instead of having to ask staff.
  describe "PATCH /registration/:slug/ce/attendance" do
    let(:day) { Date.new(2026, 7, 23) }

    it "adds a session for a day the registrant never signed in on" do
      pay_ce!
      travel_to Time.zone.local(2026, 7, 30, 10, 0) # well after the training

      expect {
        patch registration_ce_attendance_path(registration.slug, date: day.iso8601),
              params: { attendance: { entries: { "0" => { in: "02:00", out: "09:00" } } } }
      }.to change { registration.event_attendance_time_entries.count }.by(1)

      entry = registration.event_attendance_time_entries.last
      expect(entry.attendance_date).to eq(day)
      expect(entry.duration_minutes).to eq(420)
      # Registrant edits stay unattributed, like their sign-in/out taps.
      expect(entry.created_by).to be_nil
      expect(entry.updated_by).to be_nil
      expect(response).to redirect_to(registration_ce_path(registration.slug, anchor: "attendance"))
    end

    it "corrects an existing time" do
      pay_ce!
      entry = create(:event_attendance_time_entry, event_registration: registration,
        signed_in_at: Time.zone.local(2026, 7, 23, 9, 30), signed_out_at: Time.zone.local(2026, 7, 23, 12, 0))

      patch registration_ce_attendance_path(registration.slug, date: day.iso8601),
            params: { attendance: { entries: { "0" => { id: entry.id, in: "02:00", out: "05:00" } } } }

      expect(entry.reload.signed_in_at.in_time_zone("Pacific Time (US & Canada)").strftime("%H:%M")).to eq("02:00")
      expect(entry.updated_by).to be_nil
    end

    it "removes a session the registrant logged by mistake" do
      pay_ce!
      entry = create(:event_attendance_time_entry, event_registration: registration,
        signed_in_at: Time.zone.local(2026, 7, 23, 9, 30), signed_out_at: Time.zone.local(2026, 7, 23, 12, 0))

      expect {
        patch registration_ce_attendance_path(registration.slug, date: day.iso8601),
              params: { attendance: { entries: { "0" => { id: entry.id, in: "02:30", out: "05:00", _destroy: "1" } } } }
      }.to change { registration.event_attendance_time_entries.count }.by(-1)
    end

    it "reopens the day with the submitted times when the save is rejected" do
      pay_ce!

      patch registration_ce_attendance_path(registration.slug, date: day.iso8601),
            params: { attendance: { entries: { "0" => { in: "09:00", out: "02:00" } } } }

      expect(flash[:alert]).to eq("Sign-out must be after the sign-in time.")
      expect(response).to redirect_to(registration_ce_path(registration.slug, edit: day.iso8601, anchor: "attendance"))

      follow_redirect!
      expect(response.body).to include('value="09:00"')
      expect(response.body).to include('value="02:00"')
    end

    it "refuses when CE isn't paid in full" do
      license = create(:professional_license, person: registration.registrant, number: "LIC123")
      create(:continuing_education_registration, event_registration: registration, professional_license: license)

      expect {
        patch registration_ce_attendance_path(registration.slug, date: day.iso8601),
              params: { attendance: { entries: { "0" => { in: "02:00", out: "09:00" } } } }
      }.not_to change { registration.event_attendance_time_entries.count }
      expect(flash[:alert]).to be_present
    end

    it "rejects an unparseable date rather than guessing a day" do
      pay_ce!
      patch registration_ce_attendance_path(registration.slug, date: "not-a-date"),
            params: { attendance: { entries: { "0" => { in: "02:00", out: "09:00" } } } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
