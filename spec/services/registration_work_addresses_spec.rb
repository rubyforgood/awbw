require "rails_helper"

RSpec.describe RegistrationWorkAddresses do
  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:registration) { create(:event_registration, event: event, registrant: person) }
  let(:organization) { create(:organization) }

  subject(:work_addresses) { described_class.new([ registration.id ]) }

  before { registration.event_registration_organizations.create!(organization: organization) }

  it "uses the address picked on the registration's affiliation" do
    create(:address, addressable: organization, city: "Portland", state: "OR", country: "United States")
    chosen = create(:address, addressable: organization, city: "Fresno", state: "CA", country: "United States")
    create(:affiliation, person: person, organization: organization, organization_address: chosen, event_registration: registration)

    expect(work_addresses.rows.map(&:city_label)).to eq([ "Fresno, CA" ])
  end

  it "falls back to the org's oldest active address" do
    create(:address, addressable: organization, city: "Old", state: "NV", inactive: true)
    create(:address, addressable: organization, city: "Reno", state: "NV")
    create(:address, addressable: organization, city: "Elko", state: "NV")

    expect(work_addresses.rows.map(&:city_label)).to eq([ "Reno, NV" ])
  end

  it "skips the registrant's own address" do
    create(:address, addressable: person, city: "Boise", state: "ID")

    expect(work_addresses.rows.map(&:city_label)).to eq([ nil ])
  end

  it "groups registrant ids by US state, country, and city" do
    create(:address, addressable: organization, city: "Austin", state: "TX", country: "United States")
    abroad = create(:organization)
    create(:address, addressable: abroad, city: "Toronto", state: "ON", country: "Canada")
    registration.event_registration_organizations.create!(organization: abroad)

    expect(work_addresses.registrant_ids_by_state).to eq("TX" => [ person.id ])
    expect(work_addresses.registrant_ids_by_country).to eq("United States" => [ person.id ], "Canada" => [ person.id ])
    expect(work_addresses.registrant_ids_by_city_label.keys).to contain_exactly("Austin, TX", "Toronto, ON")
  end
end
