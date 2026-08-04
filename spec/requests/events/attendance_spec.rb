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

    it "shows a per-registrant Edit link to the CE edit page in the CE report" do
      log_ce_time!
      ce = registration.continuing_education_registrations.first
      get attendance_event_path(event, ce: "true")
      expect(response.body).to include(edit_continuing_education_registration_path(ce))
    end

    it "returns to the registrants page when opened from there" do
      get attendance_event_path(event, ce: "true", return_to: "registrants")
      expect(response.body).to include("← Registrants")
    end
  end

  it "forbids users who are neither admin nor the event owner" do
    sign_in create(:user)
    get attendance_event_path(event, ce: "true")
    expect(response).not_to have_http_status(:ok)
  end
end
