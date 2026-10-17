# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddressNormalizer do
  describe ".street" do
    it "matches suffix, directional, and unit spellings" do
      expect(described_class.street("123 North Main Street, Suite 4"))
        .to eq(described_class.street("123 N. Main St #4"))
    end

    it "treats apartment, unit, and # as one designator" do
      expect(described_class.street("9 Elm Rd Apt. 2")).to eq(described_class.street("9 Elm Road Unit 2"))
      expect(described_class.street("9 Elm Rd Apt #2")).to eq(described_class.street("9 Elm Rd #2"))
    end

    it "spells ordinal streets as numbers" do
      expect(described_class.street("400 First Avenue")).to eq(described_class.street("400 1st Ave"))
    end

    it "matches post office box spellings" do
      expect(described_class.street("Post Office Box 12")).to eq(described_class.street("P.O. Box 12"))
    end

    it "keeps different house numbers apart" do
      expect(described_class.street("1 Main St")).not_to eq(described_class.street("2 Main St"))
    end
  end

  it "matches saint, mount, and fort city spellings" do
    expect(described_class.city("Saint Louis")).to eq(described_class.city("St. Louis"))
    expect(described_class.city("Mount Shasta")).to eq(described_class.city("Mt Shasta"))
    expect(described_class.city("Fort Worth")).to eq(described_class.city("Ft. Worth"))
  end

  it "maps state names to their abbreviation" do
    expect(described_class.state("California")).to eq("ca")
    expect(described_class.state("C.A.")).to eq("ca")
    expect(described_class.state("New York")).to eq("ny")
    expect(described_class.state("Ontario")).to eq("ontario")
  end

  it "compares a ZIP+4 on its first five digits and ignores postal-code spacing" do
    expect(described_class.zip("90001-1234")).to eq("90001")
    expect(described_class.zip(" 90001 ")).to eq("90001")
    expect(described_class.zip("K1A 0B1")).to eq(described_class.zip("k1a0b1"))
  end

  it "reads US spellings, and a blank country in a US state, as the US" do
    expect([ "USA", "U.S.", "United States of America" ].map { |value| described_class.country(value) }.uniq).to eq([ "us" ])
    expect(described_class.country(nil, in_state: "California")).to eq("us")
    expect(described_class.country(nil, in_state: "Ontario")).to eq("")
    expect(described_class.country("Canada")).to eq("canada")
  end

  it "drops a trailing county" do
    expect(described_class.county("Los Angeles County")).to eq(described_class.county("los angeles"))
  end

  it "treats an unknown type or locality as blank" do
    expect(described_class.known_text("Unknown")).to eq("")
    expect(described_class.known_text("LA City")).to eq("la city")
  end

  describe ".signature" do
    it "matches the same place written two ways" do
      written = build(:address, street_address: "123 North Main Street", city: "Saint Louis", state: "Missouri",
                                zip_code: "63101-1234", country: nil, county: "St. Louis County", district: nil,
                                address_type: nil, locality: "Unknown")
      abbreviated = build(:address, street_address: "123 N Main St.", city: "St. Louis", state: "MO",
                                    zip_code: "63101", country: "USA", county: "St Louis", district: "",
                                    address_type: "unknown", locality: nil)

      expect(described_class.signature(written)).to eq(described_class.signature(abbreviated))
    end
  end
end
