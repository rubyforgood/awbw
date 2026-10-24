require "rails_helper"

RSpec.describe AddressTranslation do
  subject(:translation) { described_class.new }

  let(:us) { "United States" }

  describe "#country" do
    it "reads every spelling of the US found in our data as one country" do
      [ "US", "Us", "USA", "U.S.A.", "United States of America", "america", "Unites States", "Untied States",
        "Los Angeles", "LA County", "US Minor Outlying Islands" ].each do |typed|
        expect(translation.country(typed, state: "XX")).to eq(us)
      end
    end

    it "uses the dropdown's plain names" do
      expect(translation.country("Russian Federation", state: "XX")).to eq("Russia")
      expect(translation.country("RU", state: "XX")).to eq("Russia")
      expect(translation.country("CAN", state: "XX")).to eq("Canada")
      expect(translation.country("Congo, The Democratic Republic of the", state: "XX")).to eq("Democratic Republic of the Congo")
      expect(translation.country("AUSTRALIA", state: "XX")).to eq("Australia")
    end

    it "reads the FileMaker spellings the countries gem doesn't" do
      expect(translation.country("Korea", state: "XX")).to eq("South Korea")
      expect(translation.country("Republic of Ireland", state: "XX")).to eq("Ireland")
      expect(translation.country("Mexcio", state: "XX")).to eq("Mexico")
      expect(translation.country("Scotland", state: "XX")).to eq("United Kingdom")
      expect(translation.country("Republic of Armenia", state: "XX")).to eq("Armenia")
    end

    it "reads a US state code typed as the country next to that state as the US" do
      expect(translation.country("CA", state: "CA")).to eq(us)
      expect(translation.country("CA", state: "ON")).to eq("Canada")
    end

    it "falls back to the country the state implies" do
      expect(translation.country(nil, state: "CA - California")).to eq(us)
      expect(translation.country("", state: "Maryland (MD)")).to eq(us)
      expect(translation.country("-", state: "VIRGINIA")).to eq(us)
      expect(translation.country("unknown", state: "Ca.")).to eq(us)
      expect(translation.country(nil, state: "BC")).to eq("Canada")
      expect(translation.country(nil, state: "VIC")).to eq("Australia")
      expect(translation.country(nil, state: "Bucks")).to eq("United Kingdom")
      expect(translation.country(nil, state: "Ha Noi")).to eq("Vietnam")
      expect(translation.country(nil, state: "GREATER-ACCRA")).to eq("Ghana")
      expect(translation.country(nil, state: "England")).to eq("United Kingdom")
      expect(translation.country("West Africa", state: "Togo")).to eq("Togo")
    end

    it "clears a country it can't place, so every stored country is a dropdown one, and reports it" do
      expect(translation.country(" Narnia ", state: "Central Region")).to be_nil
      expect(translation.country("West Africa", state: "-")).to be_nil
      expect(translation.unmatched[:country]).to eq("Narnia" => 1, "West Africa" => 1)
    end

    it "is nil when neither the country nor the state names one" do
      [ nil, "", "   ", "-", "n/a", "None", "UNKNOWN", "not applicable" ].each do |blank|
        expect(translation.country(blank, state: "-")).to be_nil
      end
      expect(translation.unmatched[:country]).to be_empty
    end

    it "only ever answers with a dropdown country" do
      ISO3166::Country.all.each do |country|
        [ country.alpha2, country.alpha3, country.common_name, country.iso_short_name ].each do |typed|
          expect(GeographyHelper::COUNTRIES).to include(translation.country(typed, state: "XX"))
        end
      end
    end

    it "reads every country value seen in production and FileMaker into the dropdown" do
      [ "Canada", "Australia", "United Kingdom", "South Africa", "China", "Japan", "Philippines", "Cameroon",
        "Dominican Republic", "India", "Mexico", "Ireland", "New Zealand", "Russia", "Pakistan", "England", "Belgium",
        "Germany", "Hong Kong", "Rwanda", "Greece", "France", "Cayman Islands", "Norway", "South Korea", "Singapore",
        "Guam", "Korea, Republic of", "Uganda", "Zimbabwe", "Kenya", "Lebanon", "Azerbaijan", "Jamaica", "Netherlands",
        "Spain", "Hungary", "Ghana", "Switzerland", "Italy", "Iran", "Malaysia", "Nepal", "Taiwan", "Armenia" ].each do |typed|
        expect(GeographyHelper::COUNTRIES).to include(translation.country(typed, state: "XX"))
      end
    end
  end

  describe "#state" do
    it "stores a US state as its USPS code" do
      { "CA" => "CA", "ca" => "CA", "Ca." => "CA", "California" => "CA", "VIRGINIA" => "VA", "Kansas" => "KS",
        "CA - California" => "CA", "Maryland (MD)" => "MD", "Washington DC" => "DC", "PR" => "PR" }.each do |typed, code|
        expect(translation.state(typed, country: nil)).to eq(code)
      end
    end

    it "keeps a region outside the US as typed" do
      expect(translation.state(" ON ", country: "Canada")).to eq("ON")
      expect(translation.state("Georgia", country: "Georgia")).to eq("Georgia")
      expect(translation.unmatched[:state]).to be_empty
    end

    it "reports a value that reads as neither a US state nor a place abroad" do
      expect(translation.state("90401", country: "USA")).to eq("90401")
      expect(translation.unmatched[:state]).to eq("90401" => 1)
    end

    it "is nil when blank" do
      expect(translation.state("  ", country: nil)).to be_nil
    end
  end

  describe "#address_type" do
    it "reads the archive's and forms' words as the address types we store" do
      { "Home" => "personal", "cell" => "personal", "Work" => "work", "Business" => "work", "Mailing" => "mailing" }.each do |typed, type|
        expect(translation.address_type(typed)).to eq(type)
      end
      expect(translation.address_type("Vacation")).to be_nil
    end
  end

  describe "#address" do
    it "translates an address's state, country, and type, and works out its locality" do
      translated = translation.address(street_address: "1 Main St", city: "Los Angeles", state: "California",
                                       country: "USA", county: nil, address_type: "Home")

      expect(translated).to include(street_address: "1 Main St", state: "CA", country: us,
                                    address_type: "personal", locality: Address::LA_CITY)
    end

    it "reads a country from a province and marks it outside the US" do
      translated = translation.address(city: "Toronto", state: "ON", country: nil)

      expect(translated).to include(state: "ON", country: "Canada", locality: Address::OUTSIDE_USA)
    end
  end
end
