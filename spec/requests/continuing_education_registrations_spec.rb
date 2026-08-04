require "rails_helper"

RSpec.describe "ContinuingEducationRegistrations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 12_000) }
  let(:registration) { create(:event_registration, event: event) }
  let(:ce_registration) do
    create(:continuing_education_registration, event_registration: registration,
      professional_license: create(:professional_license, :placeholder, person: registration.registrant))
  end

  describe "as an admin" do
    before { sign_in admin }

    it "renders the index shell with the CE sign-in reports menu" do
      ce_registration
      get continuing_education_registrations_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CE registrations")
      expect(response.body).to include("CE sign-in reports")
    end

    it "renders the results turbo frame with only the matching event's registrations" do
      ce_registration
      other = create(:continuing_education_registration)

      get continuing_education_registrations_path(event_id: event.id),
        headers: { "Turbo-Frame" => "continuing_education_registrations_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(registration.registrant.full_name)
      expect(response.body).not_to include(other.event_registration.registrant.full_name)
    end

    it "filters by certificate status" do
      ce_registration.update!(certificate_sent_at: Time.current)
      pending = create(:continuing_education_registration)

      get continuing_education_registrations_path(certificate: "issued"),
        headers: { "Turbo-Frame" => "continuing_education_registrations_results" }

      expect(response.body).to include(registration.registrant.full_name)
      expect(response.body).not_to include(pending.event_registration.registrant.full_name)
    end

    it "renders the show page" do
      get continuing_education_registration_path(ce_registration)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CE registration")
      expect(response.body).to include(registration.registrant.full_name)
    end

    it "renders the edit page" do
      get edit_continuing_education_registration_path(ce_registration)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit CE registration")
    end

    it "offers a 'View all' link to this registration's allocations from the CE payments card" do
      get edit_continuing_education_registration_path(ce_registration)
      # sgid carries an expiry, so match the allocations href without pinning it.
      expect(response.body).to match(%r{/allocations\?[^"]*return_to=ce_registration"[^>]*>\s*View all})
    end

    it "updates hours, cost, and fills the placeholder license type, number, state + expiry in place" do
      license = ce_registration.professional_license
      patch continuing_education_registration_path(ce_registration),
            params: { continuing_education_registration: { hours: "4.5", cost_dollars: "90", license_kind: "LMFT",
              license_number: "555", license_issuing_state: "CA", license_expires_on: "2027-01-31" } }

      ce_registration.reload
      expect(ce_registration.hours).to eq(4.5)
      expect(ce_registration.cost_cents).to eq(9_000)
      # Placeholder is filled in place rather than orphaned.
      expect(ce_registration.professional_license).to eq(license)
      expect(license.reload).to have_attributes(kind: "LMFT", number: "555",
        issuing_state: "CA", expires_on: Date.new(2027, 1, 31))
    end

    it "renders a comments box on the edit page" do
      get edit_continuing_education_registration_path(ce_registration)
      expect(response.body).to include("CE comments")
      expect(response.body).to include("comment-list")
    end

    it "saves a comment added on the CE form (with the record)" do
      expect {
        patch continuing_education_registration_path(ce_registration),
              params: { continuing_education_registration: {
                hours: "6", cost_dollars: "120", license_kind: "LMFT", license_number: "555",
                comments_attributes: { "0" => { body: "Verified license by phone" } }
              } }
      }.to change(ce_registration.comments, :count).by(1)

      expect(ce_registration.comments.last.body).to eq("Verified license by phone")
    end

    it "edits the same license in place when correcting a typo (no new record)" do
      license = create(:professional_license, person: registration.registrant, kind: "LCSW", number: "11223")
      ce_registration.update!(professional_license: license)

      expect {
        patch continuing_education_registration_path(ce_registration),
              params: { continuing_education_registration: { hours: "6", cost_dollars: "120", license_kind: "LCSW", license_number: "11224" } }
      }.not_to change(ProfessionalLicense, :count)

      expect(ce_registration.reload.professional_license).to eq(license)
      expect(license.reload.number).to eq("11224")
    end

    it "links to the registrant's existing license when the typed number already matches one" do
      ce_registration
      other = create(:professional_license, person: registration.registrant, kind: "LMFT", number: "99887")

      expect {
        patch continuing_education_registration_path(ce_registration),
              params: { continuing_education_registration: { hours: "6", cost_dollars: "120", license_kind: "LMFT", license_number: "99887" } }
      }.not_to change(ProfessionalLicense, :count)

      expect(ce_registration.reload.professional_license).to eq(other)
    end

    describe "opened from the CE sign-in report (return_to=attendance)" do
      it "points the back and cancel links at the report" do
        get edit_continuing_education_registration_path(ce_registration, return_to: "attendance")
        expect(response.body).to include("CE sign-in report")
        expect(response.body).to include(attendance_event_path(event, ce: "true", anchor: "totals"))
      end

      it "returns to the report after saving" do
        patch continuing_education_registration_path(ce_registration, return_to: "attendance"),
              params: { continuing_education_registration: { hours: "6", cost_dollars: "120" } }
        expect(response).to redirect_to(attendance_event_path(event, ce: "true", anchor: "totals"))
      end

      it "returns to the report after deleting" do
        delete continuing_education_registration_path(ce_registration, return_to: "attendance")
        expect(response).to redirect_to(attendance_event_path(event, ce: "true", anchor: "totals"))
      end
    end

    it "marks the certificate issued and back to not issued" do
      patch toggle_certificate_continuing_education_registration_path(ce_registration)
      expect(ce_registration.reload.certificate_sent_at).to be_present

      patch toggle_certificate_continuing_education_registration_path(ce_registration)
      expect(ce_registration.reload.certificate_sent_at).to be_nil
    end

    it "renders the new page for a registration" do
      get new_continuing_education_registration_path(allocatable_sgid: registration.to_sgid.to_s)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Add CE registration")
    end

    it "creates a CE registration with license, hours, and cost, and sets the flag" do
      registration

      expect {
        post continuing_education_registrations_path,
             params: { allocatable_sgid: registration.to_sgid.to_s,
               continuing_education_registration: { hours: "4.5", cost_dollars: "90", license_kind: "LMFT",
                 license_number: "555", license_issuing_state: "CA", license_expires_on: "2027-01-31" } }
      }.to change { registration.continuing_education_registrations.count }.by(1)

      ce = registration.continuing_education_registrations.last
      expect(response).to redirect_to(edit_event_registration_path(registration))
      expect(ce.hours).to eq(4.5)
      expect(ce.cost_cents).to eq(9_000)
      expect(ce.professional_license).to have_attributes(kind: "LMFT", number: "555",
        issuing_state: "CA", expires_on: Date.new(2027, 1, 31))
      expect(registration.reload.ce_registered?).to be(true)
    end

    it "creates no license just from opening the new form" do
      registration
      expect {
        get new_continuing_education_registration_path(allocatable_sgid: registration.to_sgid.to_s)
      }.not_to change(ProfessionalLicense, :count)
    end

    it "leaves no orphan license when the create fails validation" do
      registration
      params = { allocatable_sgid: registration.to_sgid.to_s,
        continuing_education_registration: { hours: "-5", license_kind: "LMFT", license_number: "555" } }

      expect {
        post continuing_education_registrations_path, params: params
      }.to change(ProfessionalLicense, :count).by(0)
      expect(ContinuingEducationRegistration.count).to eq(0)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders the license picker on new when the registrant holds more than one license" do
      create(:professional_license, person: registration.registrant, kind: "LMFT", number: "111")
      create(:professional_license, person: registration.registrant, kind: "LCSW", number: "222")
      get new_continuing_education_registration_path(allocatable_sgid: registration.to_sgid.to_s)
      expect(response.body).to include("professional_license_id")
      expect(response.body).to include("Create new license")
    end

    it "omits the license picker when the registrant has a single license" do
      create(:professional_license, person: registration.registrant, kind: "LMFT", number: "111")
      get new_continuing_education_registration_path(allocatable_sgid: registration.to_sgid.to_s)
      expect(response.body).not_to include("professional_license_id")
    end

    it "points the registration at a picked license and edits it in place from the fields" do
      a = create(:professional_license, person: registration.registrant, kind: "LMFT", number: "111")
      b = create(:professional_license, person: registration.registrant, kind: "LCSW", number: "222")
      ce_registration.update!(professional_license: a)

      patch continuing_education_registration_path(ce_registration),
            params: { continuing_education_registration: { professional_license_id: b.id,
              license_kind: "LCSW", license_number: "222-B", license_issuing_state: "NY", hours: "6", cost_dollars: "120" } }

      expect(ce_registration.reload.professional_license).to eq(b)
      expect(b.reload).to have_attributes(kind: "LCSW", number: "222-B", issuing_state: "NY")
      expect(a.reload).to have_attributes(kind: "LMFT", number: "111")
    end

    it "creates a new license when 'Create new license' is picked" do
      a = create(:professional_license, person: registration.registrant, kind: "LMFT", number: "111")
      ce_registration.update!(professional_license: a)

      expect {
        patch continuing_education_registration_path(ce_registration),
              params: { continuing_education_registration: { professional_license_id: "new",
                license_kind: "LPCC", license_number: "333", hours: "6", cost_dollars: "120" } }
      }.to change(ProfessionalLicense, :count).by(1)

      expect(ce_registration.reload.professional_license).to have_attributes(kind: "LPCC", number: "333")
      expect(a.reload).to have_attributes(kind: "LMFT", number: "111")
    end

    it "removes a CE registration with no payments and clears the flag" do
      ce_registration
      delete continuing_education_registration_path(ce_registration)
      expect(ContinuingEducationRegistration.exists?(ce_registration.id)).to be(false)
      expect(registration.reload.ce_registered?).to be(false)
    end

    it "refuses to remove a CE registration that has payments" do
      create(:allocation, source: create(:payment, amount_cents: 12_000, amount_cents_remaining: 12_000),
                          allocatable: ce_registration, amount: 12_000)

      delete continuing_education_registration_path(ce_registration)

      expect(ContinuingEducationRegistration.exists?(ce_registration.id)).to be(true)
      expect(flash[:alert]).to match(/has payments/)
    end

    context "reached from the registrants roster (return_to=registrants)" do
      let(:row_path) do
        registrants_event_path(event, anchor: "registrant-row-#{registration.id}", highlight: registration.id)
      end

      it "shows the Registrants eyebrow and carries return_to through the new form" do
        get new_continuing_education_registration_path(allocatable_sgid: registration.to_sgid.to_s, return_to: "registrants")

        expect(response.body).to include("Registrants")
        expect(response.body).to match(/name="return_to"[^>]*value="registrants"/)
      end

      it "sends the create redirect back to the registrant's row" do
        post continuing_education_registrations_path,
             params: { allocatable_sgid: registration.to_sgid.to_s, return_to: "registrants",
               continuing_education_registration: { hours: "6", cost_dollars: "120", license_kind: "LMFT", license_number: "555" } }

        expect(response).to redirect_to(row_path)
      end

      it "sends the update redirect back to the registrant's row" do
        patch continuing_education_registration_path(ce_registration, return_to: "registrants"),
              params: { continuing_education_registration: { hours: "6", cost_dollars: "120", license_kind: "LMFT", license_number: "555" } }

        expect(response).to redirect_to(row_path)
      end

      it "sends the destroy redirect back to the registrant's row" do
        ce_registration
        delete continuing_education_registration_path(ce_registration, return_to: "registrants")

        expect(response).to redirect_to(row_path)
      end
    end

    describe "attendance time entries" do
      it "adds an entry from a blank row, attributed to the editing admin" do
        expect {
          patch continuing_education_registration_path(ce_registration),
                params: { continuing_education_registration: { hours: "6", cost_dollars: "120",
                  time_entries: { "0" => { signed_in_at: "2026-07-23T08:50", signed_out_at: "2026-07-23T10:34" } } } }
        }.to change { registration.event_attendance_time_entries.count }.by(1)

        entry = registration.event_attendance_time_entries.last
        # Datetime-local values are parsed in the editing admin's zone (Pacific).
        pt = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
        expect(entry.signed_in_at.in_time_zone(pt).strftime("%FT%R")).to eq("2026-07-23T08:50")
        expect(entry.signed_out_at.in_time_zone(pt).strftime("%FT%R")).to eq("2026-07-23T10:34")
        expect(entry.created_by).to eq(admin)
        expect(entry.updated_by).to eq(admin)
      end

      it "corrects an existing entry's time and stamps updated_by" do
        entry = create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 8, 50), signed_out_at: Time.zone.local(2026, 7, 23, 10, 0))

        patch continuing_education_registration_path(ce_registration),
              params: { continuing_education_registration: { hours: "6", cost_dollars: "120",
                time_entries: { "0" => { id: entry.id, signed_in_at: "2026-07-23T08:50", signed_out_at: "2026-07-23T10:34" } } } }

        expect(entry.reload.signed_out_at.in_time_zone("Pacific Time (US & Canada)").strftime("%FT%R")).to eq("2026-07-23T10:34")
        expect(entry.updated_by).to eq(admin)
      end

      it "removes an entry when its _destroy box is ticked" do
        entry = create(:event_attendance_time_entry, event_registration: registration)

        expect {
          patch continuing_education_registration_path(ce_registration),
                params: { continuing_education_registration: { hours: "6", cost_dollars: "120",
                  time_entries: { "0" => { id: entry.id, signed_in_at: "2026-07-23T08:50", _destroy: "1" } } } }
        }.to change { registration.event_attendance_time_entries.count }.by(-1)
      end

      it "ignores blank rows" do
        expect {
          patch continuing_education_registration_path(ce_registration),
                params: { continuing_education_registration: { hours: "6", cost_dollars: "120",
                  time_entries: { "0" => { signed_in_at: "", signed_out_at: "" } } } }
        }.not_to change { registration.event_attendance_time_entries.count }
      end

      it "rejects a sign-out before the sign-in with a helpful error" do
        patch continuing_education_registration_path(ce_registration),
              params: { continuing_education_registration: { hours: "6", cost_dollars: "120",
                time_entries: { "0" => { signed_in_at: "2026-07-23T10:00", signed_out_at: "2026-07-23T09:00" } } } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:alert]).to match(/after the sign-in/)
        expect(registration.event_attendance_time_entries).to be_empty
      end
    end
  end

  it "forbids non-admins" do
    sign_in create(:user)
    get edit_continuing_education_registration_path(ce_registration)
    expect(response).not_to have_http_status(:ok)
  end

  it "forbids non-admins from the index" do
    sign_in create(:user)
    get continuing_education_registrations_path
    expect(response).not_to have_http_status(:ok)
  end
end
