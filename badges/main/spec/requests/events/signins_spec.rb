require "rails_helper"

# Cross-event sign-ins: the totals table for every event the report filters reach,
# so a training's logged hours are readable without opening it.
RSpec.describe "Events sign-ins report", type: :request do
  let(:admin) { create(:user, :admin) }

  def training(title:, abbreviation:, ce: false, year: 2026)
    create(:event, title: title, abbreviation: abbreviation, facilitator_training: true,
      ce_hours_offered: (6 if ce),
      start_date: Time.zone.local(year, 7, 23, 9, 0),
      end_date: Time.zone.local(year, 7, 23, 16, 0),
      registration_close_date: Time.zone.local(year, 7, 20, 9, 0))
  end

  def log_time!(event, name: "Alice", ce: false)
    registration = create(:event_registration, event: event,
      registrant: create(:person, first_name: name, last_name: "Adams"))
    if ce
      license = create(:professional_license, person: registration.registrant, number: "LIC-#{name}")
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
    end
    create(:event_attendance_time_entry, event_registration: registration,
      signed_in_at: event.start_date, signed_out_at: event.start_date + 2.hours)
    registration
  end

  before { sign_in admin }

  # The centered header block: the scope label, the title, and the subtitle. Scoped
  # because "All events" is also the event filter's default option.
  def header_text
    Capybara.string(response.body).find("h1").find(:xpath, "..").text
  end

  it "lists a totals section per event, linking into that event's own sign-ins" do
    first = training(title: "Facilitator training A", abbreviation: "TAC-A")
    second = training(title: "Facilitator training B", abbreviation: "TAC-B")
    log_time!(first)
    log_time!(second, name: "Bob")

    get signins_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("TAC-A", "TAC-B")
    expect(response.body).to include(attendance_event_path(first, return_to: "signins"))
    expect(response.body).to include(attendance_event_path(second, return_to: "signins"))
  end

  # The header names the scope so it's legible without counting the sections.
  it "labels an unfiltered page All events and a narrowed one by abbreviation" do
    first = training(title: "Facilitator training A", abbreviation: "TAC-A")
    second = training(title: "Facilitator training B", abbreviation: "TAC-B")
    log_time!(first)
    log_time!(second, name: "Bob")

    get signins_events_path
    expect(header_text).to include("All events")

    # Narrowed to trainings: name them, so the scope is readable without counting.
    get signins_events_path(event_type: "trainings")
    expect(header_text).to include("TAC-A", "TAC-B")
    expect(header_text).not_to include("All events")

    # A single event uses the header's own linked event slot instead.
    get signins_events_path(event_id: first.id)
    expect(header_text).to include("TAC-A")
    expect(header_text).not_to include("TAC-B")
  end

  # A mixed selection must not hide the licence numbers a board audits, so one
  # CE-granting event in scope turns the CE columns on for the whole page.
  it "turns CE columns on when any event in scope grants CE" do
    plain = training(title: "Plain training", abbreviation: "PLAIN")
    ce_event = training(title: "CE training", abbreviation: "CE-1", ce: true)
    log_time!(plain)
    log_time!(ce_event, name: "Carol", ce: true)

    get signins_events_path
    expect(response.body).to include("CE sign-ins")
    expect(response.body).to include("LIC-Carol")

    get signins_events_path(event_id: plain.id)
    expect(response.body).not_to include("CE sign-ins")
  end

  it "says so when nothing in scope has logged time" do
    training(title: "Empty training", abbreviation: "EMPTY")
    get signins_events_path
    expect(response.body).to include("No sign-in time has been logged")
  end

  # The sub-nav is the point of the page family: every angle reaches every other.
  it "shows the sub-nav with Sign-ins current" do
    log_time!(training(title: "Facilitator training A", abbreviation: "TAC-A"))

    get signins_events_path

    nav = Capybara.string(response.body).find("nav[aria-label='Report views']")
    expect(nav).to have_link("Details")
    expect(nav).to have_link("Attendees")
    expect(nav).to have_link("Scholarships")
    expect(nav).to have_no_link("Sign-ins")
  end

  it "forbids a non-admin with no events of their own" do
    sign_in create(:user)
    get signins_events_path
    expect(response).not_to have_http_status(:ok)
  end
end
