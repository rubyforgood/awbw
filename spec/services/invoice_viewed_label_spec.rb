require "rails_helper"

RSpec.describe InvoiceViewedLabel do
  describe ".for" do
    it "formats the timestamp in the viewer's time zone" do
      Time.use_zone("UTC") do
        expect(described_class.for(Time.utc(2026, 11, 12, 19, 26))).to eq("Nov 12, 2026 at 7:26 PM")
      end
    end

    it "returns nil when there's no timestamp" do
      expect(described_class.for(nil)).to be_nil
    end
  end
end
