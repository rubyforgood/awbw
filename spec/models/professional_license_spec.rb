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

  describe "a license type typed into the number" do
    it "splits a known type off the front of the number" do
      expect(described_class.split_kind_from_number(kind: nil, number: "LMFT  42111")).to eq([ "LMFT", "42111" ])
      expect(described_class.split_kind_from_number(kind: "", number: "lcsw #555")).to eq([ "LCSW", "555" ])
      expect(described_class.split_kind_from_number(kind: nil, number: "LPCC12345")).to eq([ "LPCC", "12345" ])
    end

    it "leaves the number alone when the type is already set or the prefix isn't a license type" do
      expect(described_class.split_kind_from_number(kind: "LCSW", number: "LMFT 42111")).to eq([ "LCSW", "LMFT 42111" ])
      expect(described_class.split_kind_from_number(kind: nil, number: "CA 12345")).to eq([ nil, "CA 12345" ])
      expect(described_class.split_kind_from_number(kind: nil, number: "LMFT")).to eq([ nil, "LMFT" ])
    end

    it "splits it when the license saves" do
      license = create(:professional_license, person: person, kind: nil, number: "LMFT 42111")

      expect(license.reload).to have_attributes(kind: "LMFT", number: "42111")
    end

    it "finds the existing license instead of creating a second one" do
      existing = create(:professional_license, person: person, kind: "LMFT", number: "42111")

      expect(described_class.find_or_create_for(person: person, number: "LMFT 42111")).to eq(existing)
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

  describe ".located_in" do
    let!(:issued_in_california) { create(:professional_license, number: "1", issuing_state: "CA") }
    let!(:issued_in_canada) { create(:professional_license, number: "2", issuing_state: "Ontario", issuing_country: "Canada") }
    let!(:held_in_oakland) do
      create(:professional_license, number: "3", issuing_state: "NY").tap do |license|
        create(:address, addressable: license.person, city: "Oakland", state: "CA", country: "United States")
      end
    end

    it "finds licenses issued in, or held by someone living in, a US state by name or code" do
      expect(described_class.located_in("California")).to contain_exactly(issued_in_california, held_in_oakland)
      expect(described_class.located_in("ca")).to contain_exactly(issued_in_california, held_in_oakland)
    end

    it "finds licenses by province or country" do
      expect(described_class.located_in("Ontario")).to contain_exactly(issued_in_canada)
      expect(described_class.located_in("Canada")).to contain_exactly(issued_in_canada)
    end

    it "finds licenses by the holder's city, from its start" do
      expect(described_class.located_in("Oak")).to contain_exactly(held_in_oakland)
    end

    it "ignores a holder's retired address" do
      held_in_oakland.person.addresses.update_all(inactive: true)

      expect(described_class.located_in("Oakland")).to be_empty
    end
  end

  describe "issuing country" do
    it "is the US for a US state with no country named" do
      expect(create(:professional_license, issuing_state: "CA", issuing_country: "").issuing_country).to eq("United States")
    end

    it "is the US for a US state whatever country was left in the box" do
      expect(create(:professional_license, issuing_state: "CA", issuing_country: "Canada").issuing_country).to eq("United States")
    end

    it "is the US for a territory" do
      expect(create(:professional_license, issuing_state: "PR", issuing_country: "").issuing_country).to eq("United States")
    end

    it "keeps the country named beside a state outside the USA" do
      expect(create(:professional_license, issuing_state: "Ontario", issuing_country: "Canada").issuing_country).to eq("Canada")
    end

    it "stays blank for a state outside the USA" do
      expect(create(:professional_license, issuing_state: "Ontario", issuing_country: nil).issuing_country).to be_nil
    end
  end

  describe "#issuing_state_outside_usa=" do
    it "wins over the dropdown whichever is assigned first" do
      typed_first = described_class.new(issuing_state_outside_usa: "Ontario", issuing_state: "CA")
      typed_last = described_class.new(issuing_state: "CA", issuing_state_outside_usa: "Ontario")

      expect([ typed_first.issuing_state, typed_last.issuing_state ]).to eq(%w[Ontario Ontario])
    end

    it "keeps the dropdown pick when left blank" do
      expect(described_class.new(issuing_state: "CA", issuing_state_outside_usa: "").issuing_state).to eq("CA")
    end
  end
end
