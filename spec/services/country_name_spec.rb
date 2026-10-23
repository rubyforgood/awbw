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

    it "is nil for a blank or unrecognized value" do
      expect(described_class.canonical(nil)).to be_nil
      expect(described_class.canonical("")).to be_nil
      expect(described_class.canonical("Narnia")).to be_nil
    end
  end

  describe ".label" do
    it "keeps an unrecognized value as typed" do
      expect(described_class.label(" Narnia ")).to eq("Narnia")
    end
  end

  describe ".options" do
    it "lists the United States first, then every other country alphabetically" do
      expect(described_class.options.first).to eq("United States")
      expect(described_class.options.drop(1)).to eq(described_class.options.drop(1).sort)
      expect(described_class.options).to include("Canada", "Mexico")
      expect(described_class.options.count("United States")).to eq(1)
    end
  end
end
