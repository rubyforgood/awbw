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

  describe "GET /registration/:slug/ce (attendance section)" do
    it "shows a Sign in button once CE is paid and the window is open" do
      pay_ce!
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Training sign-in")
      expect(response.body).to include("Sign in")
    end

    it "shows a Sign out button and today's entries while signed in" do
      pay_ce!
      create(:event_attendance_time_entry, :open, event_registration: registration,
        signed_in_at: Time.current - 30.minutes)
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Sign out")
      expect(response.body).to include("Signed in at")
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
      expect(response.body).to include("Event begins 30 min later, at 2:00 PDT.")
      expect(response.body).not_to include("in about 2 hours")
    end

    it "hides the attendance section until CE is paid in full" do
      license = create(:professional_license, person: registration.registrant, number: "LIC123")
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      get registration_ce_path(registration.slug)
      expect(response.body).not_to include("Training sign-in")
    end
  end
end
