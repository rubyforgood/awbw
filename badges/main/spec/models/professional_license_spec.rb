require "rails_helper"

RSpec.describe ProfessionalLicense, type: :model do
  let(:person) { create(:person) }

  describe ".find_or_create_for" do
    it "creates and then reuses a license for a given number" do
      first = described_class.find_or_create_for(person: person, number: "ABC-1")
      second = described_class.find_or_create_for(person: person, number: "ABC-1")

      expect(first).to eq(second)
      expect(person.professional_licenses.count).to eq(1)
    end

    it "creates a separate license for a different number" do
      described_class.find_or_create_for(person: person, number: "ABC-1")
      described_class.find_or_create_for(person: person, number: "ABC-2")

      expect(person.professional_licenses.count).to eq(2)
    end

    it "reuses a single placeholder when no number is given" do
      first = described_class.find_or_create_for(person: person, number: "")
      second = described_class.find_or_create_for(person: person, number: nil)

      expect(first).to eq(second)
      expect(first.number).to be_nil
      expect(person.professional_licenses.count).to eq(1)
    end

    it "records the license type when given" do
      license = described_class.find_or_create_for(person: person, number: "ABC-1", kind: "LCSW")

      expect(license.kind).to eq("LCSW")
      expect(license.number).to eq("ABC-1")
    end
  end

  describe "#number_known?" do
    it "is true only when a number is present" do
      expect(build(:professional_license, number: "X")).to be_number_known
      expect(build(:professional_license, :placeholder)).not_to be_number_known
    end
  end

  describe "#expired?" do
    it "is true only for a past expiration on file" do
      expect(build(:professional_license, expires_on: Date.current - 1)).to be_expired
      expect(build(:professional_license, expires_on: Date.current + 1)).not_to be_expired
      expect(build(:professional_license, expires_on: nil)).not_to be_expired
    end
  end

  describe "validations" do
    it "rejects a duplicate kind + number for the same person" do
      create(:professional_license, person: person, kind: "LMFT", number: "DUP")
      dup = build(:professional_license, person: person, kind: "LMFT", number: "DUP")

      expect(dup).not_to be_valid
    end

    it "allows (and persists) the same number under a different kind" do
      create(:professional_license, person: person, kind: "LMFT", number: "DUP")

      expect {
        create(:professional_license, person: person, kind: "LCSW", number: "DUP")
      }.to change(described_class, :count).by(1)
    end
  end

  describe "removal guard" do
    let(:license) { create(:professional_license, person: person, number: "GUARD-1") }

    def attach_ce(paid: false)
      registration = create(:event_registration, registrant: person)
      ce = create(:continuing_education_registration, event_registration: registration, professional_license: license, cost_cents: 10_000)
      return ce unless paid
      create(:allocation, source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
                          allocatable: ce, amount: 10_000)
      ce
    end

    it "is removable with no CE registrations" do
      expect(license).to be_removable
      expect { license.destroy }.to change(described_class, :count).by(-1)
    end

    it "refuses to destroy when an unpaid CE registration exists" do
      attach_ce(paid: false)
      expect(license.reload).not_to be_removable
      expect { license.destroy }.not_to change(described_class, :count)
    end

    it "refuses to destroy when a CE registration carries payments" do
      attach_ce(paid: true)
      expect(license.reload).not_to be_removable
      expect { license.destroy }.not_to change(described_class, :count)
    end
  end

  describe "#used_for_ce?" do
    let(:license) { create(:professional_license, person: person, number: "USED-1") }

    it "is false without CE registrations and true once one exists" do
      expect(license).not_to be_used_for_ce
      registration = create(:event_registration, registrant: person)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(license.reload).to be_used_for_ce
    end
  end
end
