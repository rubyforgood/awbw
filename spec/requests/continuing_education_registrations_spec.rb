require "rails_helper"

RSpec.describe "ContinuingEducationRegistrations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 12_000) }
  let(:registration) { create(:event_registration, event: event, ce_requested: true) }
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

    it "updates hours, cost, and promotes the placeholder license in place" do
      license = ce_registration.professional_license
      patch continuing_education_registration_path(ce_registration),
            params: { continuing_education_registration: { hours: "4.5", cost_dollars: "90", license_number: "LMFT 555" } }

      ce_registration.reload
      expect(ce_registration.hours).to eq(4.5)
      expect(ce_registration.cost_cents).to eq(9_000)
      # Placeholder is promoted in place rather than orphaned.
      expect(ce_registration.professional_license).to eq(license)
      expect(license.reload.number).to eq("LMFT 555")
    end

    it "marks the certificate issued and back to not issued" do
      patch toggle_certificate_continuing_education_registration_path(ce_registration)
      expect(ce_registration.reload.certificate_sent_at).to be_present

      patch toggle_certificate_continuing_education_registration_path(ce_registration)
      expect(ce_registration.reload.certificate_sent_at).to be_nil
    end

    it "removes a CE registration with no payments and clears the flag" do
      ce_registration
      delete continuing_education_registration_path(ce_registration)
      expect(ContinuingEducationRegistration.exists?(ce_registration.id)).to be(false)
      expect(registration.reload.ce_requested).to be(false)
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
