require "rails_helper"

RSpec.describe MoneyParser do
  describe ".cents" do
    it "returns nil for a blank amount so the caller can use its default" do
      expect(described_class.cents(nil)).to be_nil
      expect(described_class.cents("")).to be_nil
      expect(described_class.cents("   ")).to be_nil
    end

    it "converts whole dollars and trims whitespace" do
      expect(described_class.cents("50")).to eq(5_000)
      expect(described_class.cents(" 50 ")).to eq(5_000)
      expect(described_class.cents("0")).to eq(0)
    end

    it "keeps up to two decimal places" do
      expect(described_class.cents("99.5")).to eq(9_950)
      expect(described_class.cents("99.50")).to eq(9_950)
      expect(described_class.cents("0.01")).to eq(1)
    end

    it "rejects anything that is not a non-negative dollar amount" do
      %w[fifty -5 5. .5 1,000 10.999 $50].each do |value|
        expect(described_class.cents(value)).to eq(described_class::INVALID), value
      end
    end
  end

  describe ".invalid?" do
    it "recognizes the invalid sentinel but not blank or a parsed amount" do
      expect(described_class.invalid?(described_class::INVALID)).to be(true)
      expect(described_class.invalid?(nil)).to be(false)
      expect(described_class.invalid?(0)).to be(false)
    end
  end
end
