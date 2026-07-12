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

    it "renders the edit page" do
      get edit_continuing_education_registration_path(ce_registration)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit CE registration")
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
  end

  it "forbids non-admins" do
    sign_in create(:user)
    get edit_continuing_education_registration_path(ce_registration)
    expect(response).not_to have_http_status(:ok)
  end
end
