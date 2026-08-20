require "rails_helper"

RSpec.describe NumberFormatter do
  describe ".plain" do
    it "drops insignificant trailing zeros" do
      expect(described_class.plain(6.0)).to eq("6")
      expect(described_class.plain(1.5)).to eq("1.5")
      expect(described_class.plain(0.25)).to eq("0.25")
      expect(described_class.plain(BigDecimal("6"))).to eq("6")
    end

    it "returns nil for a blank input" do
      expect(described_class.plain(nil)).to be_nil
      expect(described_class.plain("")).to be_nil
    end
  end
end
