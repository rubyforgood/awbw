require "rails_helper"

RSpec.describe "People professional licenses", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "renders the professional licenses section on the edit page" do
    person = create(:person)
    create(:professional_license, person: person, number: "LMFT 90210")

    get edit_person_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Professional licenses")
    expect(response.body).to include("LMFT 90210")
  end

  it "adds a license through the person form" do
    person = create(:person)

    expect {
      patch person_path(person), params: { person: {
        professional_licenses_attributes: { "0" => { number: "LCSW 11223", kind: "LCSW", issuing_state: "CA" } }
      } }
    }.to change { person.professional_licenses.count }.by(1)

    expect(person.professional_licenses.last.number).to eq("LCSW 11223")
  end

  it "ignores a blank license row" do
    person = create(:person)

    expect {
      patch person_path(person), params: { person: {
        professional_licenses_attributes: { "0" => { number: "", kind: "", issuing_state: "", expires_on: "" } }
      } }
    }.not_to change { person.professional_licenses.count }
  end

  it "removes a license with no CE registrations" do
    person = create(:person)
    license = create(:professional_license, person: person, number: "GONE-1")

    expect {
      patch person_path(person), params: { person: {
        professional_licenses_attributes: { "0" => { id: license.id, _destroy: "1" } }
      } }
    }.to change { person.professional_licenses.count }.by(-1)
  end

  it "keeps a license whose CE registration has no payments" do
    person = create(:person)
    license = create(:professional_license, person: person, number: "UNPAID-1")
    registration = create(:event_registration, registrant: person)
    create(:continuing_education_registration, event_registration: registration, professional_license: license, cost_cents: 10_000)

    patch person_path(person), params: { person: {
      professional_licenses_attributes: { "0" => { id: license.id, _destroy: "1" } }
    } }

    expect(ProfessionalLicense.exists?(license.id)).to be(true)
  end

  it "keeps a license whose CE registration has payments" do
    person = create(:person)
    license = create(:professional_license, person: person, number: "PAID-1")
    registration = create(:event_registration, registrant: person)
    ce = create(:continuing_education_registration, event_registration: registration, professional_license: license, cost_cents: 10_000)
    create(:allocation, source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
                        allocatable: ce, amount: 10_000)

    patch person_path(person), params: { person: {
      professional_licenses_attributes: { "0" => { id: license.id, _destroy: "1" } }
    } }

    expect(ProfessionalLicense.exists?(license.id)).to be(true)
  end

  # The person form is admin-only today, so the per-license guard is dormant. These
  # simulate the future state where PersonPolicy lets an owner reach the form, to
  # prove the server-side backstop (ProfessionalLicensePolicy) holds before we flip it.
  context "when a non-admin owner can reach the form (simulating the future PersonPolicy)" do
    let(:owner) { create(:user, :with_person) }
    let(:person) { owner.person }

    before do
      sign_in owner
      allow_any_instance_of(PersonPolicy).to receive(:edit?).and_return(true)
      allow_any_instance_of(PersonPolicy).to receive(:update?).and_return(true)
    end

    it "ignores edits to a CE-tied license but applies edits to an unlocked one" do
      locked = create(:professional_license, person: person, number: "LOCKED-1", kind: "LMFT")
      registration = create(:event_registration, registrant: person)
      create(:continuing_education_registration, event_registration: registration, professional_license: locked)
      unlocked = create(:professional_license, person: person, number: "OPEN-1", kind: "LCSW")

      patch person_path(person), params: { person: {
        professional_licenses_attributes: {
          "0" => { id: locked.id, kind: "HACKED" },
          "1" => { id: unlocked.id, kind: "LPCC" }
        }
      } }

      expect(locked.reload.kind).to eq("LMFT")
      expect(unlocked.reload.kind).to eq("LPCC")
    end

    it "blocks deleting a CE-tied license" do
      locked = create(:professional_license, person: person, number: "LOCKED-2")
      registration = create(:event_registration, registrant: person)
      create(:continuing_education_registration, event_registration: registration, professional_license: locked)

      patch person_path(person), params: { person: {
        professional_licenses_attributes: { "0" => { id: locked.id, _destroy: "1" } }
      } }

      expect(ProfessionalLicense.exists?(locked.id)).to be(true)
    end
  end
end
