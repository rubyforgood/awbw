require "rails_helper"

RSpec.describe CountryName do
  describe ".canonical" do
    it "reads the many ways registrants type the US as one country" do
      %w[US usa U.S.A. America].push("United States of America", "united states").each do |typed|
        expect(described_class.canonical(typed)).to eq("United States")
      end
    end

    it "resolves ISO codes and other names to the common name" do
      expect(described_class.canonical("CAN")).to eq("Canada")
      expect(described_class.canonical("UK")).to eq("United Kingdom")
      expect(described_class.canonical(" mexico ")).to eq("Mexico")
    end

    it "reads the misspellings and older names found in AWBW's data" do
      expect(described_class.canonical("Untied States")).to eq("United States")
      expect(described_class.canonical("US Minor Outlying Islands")).to eq("United States")
      expect(described_class.canonical("Republic of Ireland")).to eq("Ireland")
      expect(described_class.canonical("Scotland")).to eq("United Kingdom")
      expect(described_class.canonical("Korea")).to eq("South Korea")
    end

    it "is nil for a blank or unrecognized value" do
      expect(described_class.canonical(nil)).to be_nil
      expect(described_class.canonical("")).to be_nil
      expect(described_class.canonical("Narnia")).to be_nil
    end
  end

  describe ".resolve" do
    it "uses the typed country when it's recognized" do
      expect(described_class.resolve("USA", state: "TX")).to eq("United States")
      expect(described_class.resolve("Canada", state: "ON")).to eq("Canada")
    end

    it "reads a US state code typed as the country next to that state as the US" do
      expect(described_class.resolve("CA", state: "CA")).to eq("United States")
      expect(described_class.resolve("CA", state: "ON")).to eq("Canada")
    end

    it "falls back to the country the state implies" do
      expect(described_class.resolve(nil, state: "CA - California")).to eq("United States")
      expect(described_class.resolve("", state: "Maryland (MD)")).to eq("United States")
      expect(described_class.resolve("-", state: "VIRGINIA")).to eq("United States")
      expect(described_class.resolve("unknown", state: "CA")).to eq("United States")
      expect(described_class.resolve(nil, state: "BC")).to eq("Canada")
      expect(described_class.resolve(nil, state: "Bucks")).to eq("United Kingdom")
      expect(described_class.resolve(nil, state: "Ha Noi")).to eq("Vietnam")
      expect(described_class.resolve("West Africa", state: "Togo")).to eq("Togo")
      expect(described_class.resolve(nil, state: "England")).to eq("United Kingdom")
    end

    it "keeps an unrecognized country as typed when the state says nothing" do
      expect(described_class.resolve(" Narnia ", state: "Central Region")).to eq("Narnia")
    end

    it "is nil when neither the country nor the state names one" do
      [ nil, "", "   ", "-", "--", "n/a", "N/A", "None", "UNKNOWN", "not applicable" ].each do |blank|
        expect(described_class.resolve(blank, state: "-")).to be_nil
      end
      expect(described_class.resolve(nil, state: "Kenmore")).to be_nil
    end
  end

  describe ".options" do
    it "lists the United States first, then every other country alphabetically" do
      expect(described_class.options.first).to eq("United States")
      expect(described_class.options.drop(1)).to eq(described_class.options.drop(1).sort)
      expect(described_class.options).to include("Canada", "Mexico")
      expect(described_class.options.count("United States")).to eq(1)
      expect(described_class.options).not_to include("United States Minor Outlying Islands")
    end
  end
end
