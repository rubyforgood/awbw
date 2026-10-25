require "rails_helper"

RSpec.describe PersonLocations do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:affiliation) { create(:affiliation, person: person, organization: organization) }

  subject(:locations) { described_class.new([ person.id ]) }

  it "uses the address picked on the affiliation" do
    create(:address, addressable: organization, city: "Portland", state: "OR", country: "United States")
    chosen = create(:address, addressable: organization, city: "Fresno", state: "CA", country: "United States")
    affiliation.update!(organization_address: chosen)

    expect(locations.rows.map(&:city_label)).to eq([ "Fresno, CA" ])
  end

  it "falls back to the org's oldest active address" do
    create(:address, addressable: organization, city: "Old", state: "NV", inactive: true)
    create(:address, addressable: organization, city: "Reno", state: "NV")
    create(:address, addressable: organization, city: "Elko", state: "NV")

    expect(locations.rows.map(&:city_label)).to eq([ "Reno, NV" ])
  end

  it "counts every active affiliation" do
    create(:address, addressable: organization, city: "Reno", state: "NV")
    other = create(:organization)
    create(:address, addressable: other, city: "Elko", state: "NV")
    create(:affiliation, person: person, organization: other)

    expect(locations.rows.map(&:city_label)).to contain_exactly("Reno, NV", "Elko, NV")
  end

  it "prefers the work address over the person's own" do
    create(:address, addressable: organization, city: "Reno", state: "NV")
    create(:address, addressable: person, city: "Boise", state: "ID")

    expect(locations.rows.map(&:city_label)).to eq([ "Reno, NV" ])
  end

  it "skips an ended affiliation today" do
    create(:address, addressable: organization, city: "Reno", state: "NV")
    affiliation.update!(end_date: 1.month.ago.to_date)
    create(:address, addressable: person, city: "Boise", state: "ID")

    expect(locations.rows.map(&:city_label)).to eq([ "Boise, ID" ])
  end

  describe "on a date" do
    before do
      create(:address, addressable: organization, city: "Reno", state: "NV")
      create(:address, addressable: person, city: "Boise", state: "ID")
    end

    it "counts an affiliation that was active then, even if it has ended since" do
      affiliation.update!(start_date: Date.new(2024, 1, 1), end_date: Date.new(2025, 1, 1))

      expect(described_class.new([ person.id ], on: Date.new(2024, 6, 1)).rows.map(&:city_label)).to eq([ "Reno, NV" ])
    end

    it "skips an affiliation that started after it" do
      affiliation.update!(start_date: Date.new(2025, 1, 1))

      expect(described_class.new([ person.id ], on: Date.new(2024, 6, 1)).rows.map(&:city_label)).to eq([ "Boise, ID" ])
    end
  end

  # Address#ranked_for_owner: active work, else latest-edited active personal,
  # else inactive personal, else inactive work.
  it "falls back to the address that stands for the person" do
    affiliation.destroy!
    create(:address, addressable: person, city: "Boise", state: "ID", address_type: "personal")
    create(:address, addressable: person, city: "Nampa", state: "ID", address_type: "work")

    expect(locations.rows.map { |row| [ row.city_label, row.organization_id ] }).to eq([ [ "Nampa, ID", nil ] ])
  end

  it "places a person by a retired address rather than nowhere" do
    create(:address, addressable: person, city: "Boise", state: "ID", address_type: "personal", inactive: true)

    expect(locations.rows.map(&:city_label)).to eq([ "Boise, ID" ])
  end

  it "has no row for someone with no work or own address" do
    expect(locations.rows).to be_empty
  end

  # A relation stays a subquery, so a whole-population lookup never inlines every
  # id (the attendees index builds its filter options that way).
  it "keeps a relation as a subquery instead of plucking its ids" do
    create(:address, addressable: organization, city: "Austin", state: "TX")

    queries = []
    subscriber = ->(*, payload) { queries << payload[:sql] }
    rows = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      described_class.new(Person.where(id: person.id)).rows
    end

    expect(rows.map(&:city_label)).to eq([ "Austin, TX" ])
    expect(queries.grep(/FROM `affiliations`/).first).to include("SELECT `people`.`id` FROM `people`")
  end

  it "groups registrant ids by US state, country, and city" do
    create(:address, addressable: organization, city: "Austin", state: "TX", country: "United States")
    abroad = create(:organization)
    create(:address, addressable: abroad, city: "Toronto", state: "ON", country: "Canada")
    create(:affiliation, person: person, organization: abroad)

    expect(locations.registrant_ids_by_state).to eq("TX" => [ person.id ])
    expect(locations.registrant_ids_by(:country)).to eq("United States" => [ person.id ], "Canada" => [ person.id ])
    expect(locations.registrant_ids_by_city_label.keys).to contain_exactly("Austin, TX", "Toronto, ON")
  end

  it "groups by any other location field the address carries" do
    create(:address, addressable: organization, city: "Austin", state: "TX",
           zip_code: "78701", county: "Travis", locality: Address::OUTSIDE_CA, district: "Austin ISD")

    expect(locations.registrant_ids_by(:zip_code)).to eq("78701" => [ person.id ])
    expect(locations.registrant_ids_by(:locality)).to eq(Address::OUTSIDE_CA => [ person.id ])
    expect(locations.registrant_ids_by(:district)).to eq("Austin ISD" => [ person.id ])
  end

  describe "#matching" do
    before do
      create(:address, addressable: organization, city: "Austin", state: "TX", county: "Travis", country: "United States")
      abroad = create(:organization)
      create(:address, addressable: abroad, city: "Toronto", state: "ON", county: "York", country: "Canada")
      create(:affiliation, person: person, organization: abroad)
    end

    # One call, not two: chaining them is what lets someone working in two
    # places answer a city from one and a county from the other.
    it "tests every field against the same address" do
      expect(locations.matching(city: "toronto", country: "Canada")).to be_present
      expect(locations.matching(city: "toronto", country: "United States")).to be_empty
      expect(locations.matching(city: "toronto", county: "Travis")).to be_empty
    end

    it "matches a searched field on a substring and the rest whole, both case-insensitively" do
      expect(locations.matching(city: "AUST")).to be_present
      expect(locations.matching(state: "tx")).to be_present
      expect(locations.matching(county: "Trav")).to be_empty
    end

    it "rejects a field that isn't a location" do
      expect { locations.matching(street_address: "908 N 6th St") }.to raise_error(ArgumentError)
    end
  end

  describe ".filters_from" do
    it "folds the county option's own state into the state filter" do
      expect(described_class.filters_from(county: "CA|Los Angeles")).to eq(state: "CA", county: "Los Angeles")
      expect(described_class.filters_from(county: "CA::Los Angeles", city: "pas")).to eq(state: "CA", county: "Los Angeles", city: "pas")
    end

    it "keeps a bare county name, and drops blanks" do
      expect(described_class.filters_from(county: "Los Angeles", state: "")).to eq(county: "Los Angeles")
      expect(described_class.filters_from(state: nil, county: nil, city: nil)).to eq({})
    end

    it "reports no possible match when the state and the county's state disagree" do
      expect(described_class.filters_from(state: "CA", county: "OR|Multnomah")).to be_nil
      expect(described_class.filters_from(county: "CA|")).to be_nil
    end
  end

  describe "#candidate_values" do
    # Option lists are built from the whole reportable population, so they read the
    # address tables directly rather than resolving a row per person.
    it "lists the values the affiliated orgs' and people's own addresses carry" do
      create(:address, addressable: organization, state: "TX", county: "Travis")
      create(:address, addressable: person, state: "ID", county: "Ada")

      expect(locations.candidate_values(:state)).to eq(%w[ID TX])
      expect(locations.candidate_values(:state, :county)).to eq([ [ "ID", "Ada" ], [ "TX", "Travis" ] ])
    end

    it "skips addresses missing any of the fields asked for" do
      create(:address, addressable: organization, state: "TX", county: "")

      expect(locations.candidate_values(:state)).to eq([ "TX" ])
      expect(locations.candidate_values(:state, :county)).to be_empty
    end
  end
end
