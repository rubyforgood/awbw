# frozen_string_literal: true

require "rails_helper"

# Merging two people must consolidate their professional licenses without ever
# destroying a license that carries CE history. A license identified by the same
# (kind, number) collides on the unique index, so the merge collapses the two into
# one — but the losing license's CE registrations must move to the survivor, not
# cascade away (ProfessionalLicense refuses to destroy a license with CE regs).
RSpec.describe "People dedupe — professional licenses", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def merge!(keep:, delete:)
    post dedupe_perform_people_path, params: {
      person_to_keep_id: keep.id,
      person_to_delete_id: delete.id
    }
  end

  # A license on `person` plus a CE registration hanging off it (at its own event).
  def license_with_ce(person, number:, kind: "LMFT")
    license = create(:professional_license, person: person, number: number, kind: kind)
    registration = create(:event_registration, registrant: person)
    create(:continuing_education_registration, event_registration: registration, professional_license: license)
    license
  end

  describe "colliding licenses that both carry CE (the reported failure)" do
    let!(:keep) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane@real.test") }
    let!(:delete_rec) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane2@real.test") }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "merges successfully instead of erroring on the destroy" do
      merge!(keep: keep, delete: delete_rec)

      expect(response).to redirect_to(people_path)
      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(response.body).not_to include("Error merging")
    end

    it "leaves the keeper with a single license holding both CE registrations" do
      merge!(keep: keep, delete: delete_rec)

      expect(Person.exists?(delete_rec.id)).to be false
      expect(keep.reload.professional_licenses.count).to eq(1)

      survivor = keep.professional_licenses.first
      expect(survivor.continuing_education_registrations.count).to eq(2)
      expect(ContinuingEducationRegistration.count).to eq(2)
    end
  end

  describe "both licenses have an empty number (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "ends up with just one license on the keeper" do
      merge!(keep: keep, delete: delete_rec)

      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(2)
    end
  end

  describe "licenses with different numbers (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: "LIC-A") }
    let!(:delete_license) { license_with_ce(delete_rec, number: "LIC-B") }

    it "keeps both licenses on the keeper, each with its own CE" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.order(:number).pluck(:number)).to eq(%w[LIC-A LIC-B])
      keep.professional_licenses.each do |license|
        expect(license.continuing_education_registrations.count).to eq(1)
      end
    end
  end

  describe "one license numbered, the other empty (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: "LIC-A") }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "keeps them as two separate licenses on the keeper" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.count).to eq(2)
      expect(keep.professional_licenses.map(&:number)).to contain_exactly("LIC-A", nil)
    end
  end

  describe "only the losing license carries CE (colliding placeholders)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { create(:professional_license, person: keep, number: nil, kind: "LMFT") }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "moves the losing license's CE onto the surviving license" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(1)
    end
  end

  describe "only the surviving license carries CE (losing placeholder is empty)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { create(:professional_license, person: delete_rec, number: nil, kind: "LMFT") }

    it "discards the empty losing license and keeps the survivor's CE" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(1)
    end
  end
end
