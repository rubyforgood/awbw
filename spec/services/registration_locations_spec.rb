require "rails_helper"

RSpec.describe RegistrationLocations do
  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:registration) { create(:event_registration, event: event, registrant: person) }
  let(:organization) { create(:organization) }

  subject(:locations) { described_class.new([ registration.id ]) }

  before { registration.event_registration_organizations.create!(organization: organization) }

  it "uses the address picked on the registration's affiliation" do
    create(:address, addressable: organization, city: "Portland", state: "OR", country: "United States")
    chosen = create(:address, addressable: organization, city: "Fresno", state: "CA", country: "United States")
    create(:affiliation, person: person, organization: organization, organization_address: chosen, event_registration: registration)

    expect(locations.rows.map(&:city_label)).to eq([ "Fresno, CA" ])
  end

  it "falls back to the org's oldest active address" do
    create(:address, addressable: organization, city: "Old", state: "NV", inactive: true)
    create(:address, addressable: organization, city: "Reno", state: "NV")
    create(:address, addressable: organization, city: "Elko", state: "NV")

    expect(locations.rows.map(&:city_label)).to eq([ "Reno, NV" ])
  end

  it "prefers the work address over the registrant's own" do
    create(:address, addressable: organization, city: "Reno", state: "NV")
    create(:address, addressable: person, city: "Boise", state: "ID")

    expect(locations.rows.map(&:city_label)).to eq([ "Reno, NV" ])
  end

  it "falls back to the registrant's primary address when the linked org has none" do
    create(:address, addressable: person, city: "Boise", state: "ID")
    create(:address, addressable: person, city: "Nampa", state: "ID", primary: true)

    expect(locations.rows.map(&:city_label)).to eq([ "Nampa, ID" ])
  end

  it "falls back to the registrant's own address when no org is linked" do
    unlinked = create(:event_registration, event: event)
    create(:address, addressable: unlinked.registrant, city: "Boise", state: "ID")

    rows = described_class.new([ unlinked.id ]).rows
    expect(rows.map { |row| [ row.city_label, row.organization_id ] }).to eq([ [ "Boise, ID", nil ] ])
  end

  it "leaves a located-nowhere linked registration as an Unknown row" do
    expect(locations.rows.map(&:city_label)).to eq([ nil ])
  end

  it "has no row for an unlinked registrant with no address" do
    expect(described_class.new([ create(:event_registration, event: event).id ]).rows).to be_empty
  end

  it "groups registrant ids by US state, country, and city" do
    create(:address, addressable: organization, city: "Austin", state: "TX", country: "United States")
    abroad = create(:organization)
    create(:address, addressable: abroad, city: "Toronto", state: "ON", country: "Canada")
    registration.event_registration_organizations.create!(organization: abroad)

    expect(locations.registrant_ids_by_state).to eq("TX" => [ person.id ])
    expect(locations.registrant_ids_by_country).to eq("United States" => [ person.id ], "Canada" => [ person.id ])
    expect(locations.registrant_ids_by_city_label.keys).to contain_exactly("Austin, TX", "Toronto, ON")
  end
end
