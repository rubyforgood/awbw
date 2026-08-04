require "rails_helper"

RSpec.describe "Events attendance report", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) do
    create(:event, ce_hours_offered: 6,
      start_date: Time.zone.local(2026, 7, 23, 9, 0),
      end_date: Time.zone.local(2026, 7, 23, 16, 0),
      registration_close_date: Time.zone.local(2026, 7, 20, 9, 0))
  end
  let(:registration) do
    create(:event_registration, event: event, registrant: create(:person, first_name: "Alice", last_name: "Adams"))
  end

  def log_ce_time!
    license = create(:professional_license, person: registration.registrant, number: "AAA111")
    create(:continuing_education_registration, event_registration: registration, professional_license: license)
    create(:event_attendance_time_entry, event_registration: registration,
      signed_in_at: Time.zone.local(2026, 7, 23, 8, 50), signed_out_at: Time.zone.local(2026, 7, 23, 10, 34))
  end

  describe "as an admin" do
    before { sign_in admin }

    it "renders the CE report with license number and hours when ce=true" do
      log_ce_time!
      get attendance_event_path(event, ce: "true")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CE sign-in report")
      expect(response.body).to include("Alice Adams")
      expect(response.body).to include("AAA111")
    end

    it "renders the generic attendance report without CE scoping" do
      get attendance_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Attendance sign-in")
      expect(response.body).not_to include("CE sign-in report")
    end

    it "makes each row link to the CE edit page and the name link to the CE callout" do
      log_ce_time!
      ce = registration.continuing_education_registrations.first
      get attendance_event_path(event, ce: "true")
      expect(response.body).to include(edit_continuing_education_registration_path(ce)) # whole-row link
      expect(response.body).to include(registration_ce_path(registration.slug))         # name link
    end

    it "groups sessions by person by default" do
      log_ce_time!
      get attendance_event_path(event, ce: "true")
      expect(response.body).to include("Sessions by person")
      expect(response.body).not_to include("Sessions by day")
    end

    it "groups sessions by day when toggled" do
      log_ce_time!
      get attendance_event_path(event, ce: "true", group: "day")
      expect(response.body).to include("Sessions by day")
      expect(response.body).to include("Day 1 ·")
    end

    it "links session rows to the registration edit page on the generic report" do
      log_ce_time!
      get attendance_event_path(event)
      expect(response.body).to include("#{edit_event_registration_path(registration)}?return_to=attendance")

      get attendance_event_path(event, group: "day")
      expect(response.body).to include("#{edit_event_registration_path(registration)}?return_to=attendance")
    end

    it "links session rows to the CE edit page on the CE report" do
      log_ce_time!
      ce = registration.continuing_education_registrations.first
      get attendance_event_path(event, ce: "true")
      expect(response.body).to include("#{edit_continuing_education_registration_path(ce)}?return_to=attendance")
      expect(response.body).not_to include("#{edit_event_registration_path(registration)}?return_to=attendance")
    end

    # The name link opens the registrant-facing callout; its eyebrow has to lead back
    # to the report, not to the registration edit default two hops away.
    it "sends the name link to a CE callout that points back at the report" do
      log_ce_time!
      get attendance_event_path(event, ce: "true")
      expect(response.body).to include("#{registration_ce_path(registration.slug)}?return_to=attendance")

      get registration_ce_path(registration.slug, return_to: "attendance")
      expect(response.body).to include("Back to CE sign-in report")
      expect(response.body).to include(attendance_event_path(event, ce: "true", anchor: "totals"))
    end

    it "returns to the registrants page when opened from there" do
      get attendance_event_path(event, ce: "true", return_to: "registrants")
      expect(response.body).to include("← Registrants")
    end

    it "shows the event's daily times in the page header and each day header" do
      # Pin the viewer to UTC so the times render exactly as the event was built
      # (requests otherwise display in the admin's zone, Pacific by default).
      sign_in create(:user, :admin, time_zone: "UTC")
      log_ce_time!
      get attendance_event_path(event, ce: "true", group: "day")
      expect(response.body).to include("#{event.decorate.date_range} · 9 am - 4 pm UTC")
      expect(response.body).to include("Day 1 · #{Date.new(2026, 7, 23).strftime("%A, %b %-d")} · 9 am - 4 pm UTC")
    end

    # The chip flags an entry with no sign-out, so on a per-day table it has to be
    # about that day — otherwise one forgotten sign-out lights up every later day too,
    # which is exactly what staff are scanning the report to find.
    it "flags 'signed in' only on the day whose entry is still open" do
      event.update!(end_date: Time.zone.local(2026, 7, 24, 16, 0))
      license = create(:professional_license, person: registration.registrant, number: "AAA111")
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      create(:event_attendance_time_entry, :open, event_registration: registration,
        signed_in_at: Time.zone.local(2026, 7, 23, 9, 0))
      create(:event_attendance_time_entry, event_registration: registration,
        signed_in_at: Time.zone.local(2026, 7, 24, 9, 0), signed_out_at: Time.zone.local(2026, 7, 24, 12, 0))

      get attendance_event_path(event, ce: "true", group: "day")

      sections = Capybara.string(response.body).all("section")
      day_one = sections.find { |section| section.text.squish.start_with?("Day 1 ·") }
      day_two = sections.find { |section| section.text.squish.start_with?("Day 2 ·") }
      expect(day_one).to have_css("span.bg-teal-50", text: "signed in")
      expect(day_two).to have_no_css("span.bg-teal-50")
    end

    it "warns when the event runs longer than the report's 5-day cap" do
      event.update!(end_date: Time.zone.local(2026, 7, 30, 16, 0))
      get attendance_event_path(event)
      expect(response.body).to include("only the first 5 days")
    end
  end

  it "forbids users who are neither admin nor the event owner" do
    sign_in create(:user)
    get attendance_event_path(event, ce: "true")
    expect(response).not_to have_http_status(:ok)
  end
end
