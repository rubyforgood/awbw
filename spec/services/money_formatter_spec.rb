require "rails_helper"

RSpec.describe MoneyFormatter do
  describe ".dollars_from_cents" do
    it "drops the cents for whole-dollar amounts" do
      expect(described_class.dollars_from_cents(150_000)).to eq("$1,500")
      expect(described_class.dollars_from_cents(5_000)).to eq("$50")
      expect(described_class.dollars_from_cents(0)).to eq("$0")
    end

    it "keeps the cents when present" do
      expect(described_class.dollars_from_cents(75_050)).to eq("$750.50")
      expect(described_class.dollars_from_cents(1_099)).to eq("$10.99")
      expect(described_class.dollars_from_cents(1_234_556)).to eq("$12,345.56")
    end

    it "coerces nil to zero" do
      expect(described_class.dollars_from_cents(nil)).to eq("$0")
    end
  end

  describe ".signed_dollars_from_cents" do
    it "keeps a leading minus for negative amounts" do
      expect(described_class.signed_dollars_from_cents(-120_000)).to eq("-$1,200")
      expect(described_class.signed_dollars_from_cents(-75_050)).to eq("-$750.50")
    end

    it "matches dollars_from_cents for zero and positive amounts" do
      expect(described_class.signed_dollars_from_cents(150_000)).to eq("$1,500")
      expect(described_class.signed_dollars_from_cents(0)).to eq("$0")
    end
  end

  describe ".compact_from_cents" do
    it "uses plain dollars under a thousand" do
      expect(described_class.compact_from_cents(75_000)).to eq("$750")
      expect(described_class.compact_from_cents(90_000)).to eq("$900")
    end

    it "abbreviates thousands and millions, trimming trailing zeros" do
      expect(described_class.compact_from_cents(750_000)).to eq("$7.5k")
      expect(described_class.compact_from_cents(1_000_000)).to eq("$10k")
      expect(described_class.compact_from_cents(120_000_000)).to eq("$1.2m")
    end

    it "rounds to whole units at precision 0" do
      expect(described_class.compact_from_cents(1_517_000, precision: 0)).to eq("$15k")
      expect(described_class.compact_from_cents(420_000, precision: 0)).to eq("$4k")
    end
  end
end
