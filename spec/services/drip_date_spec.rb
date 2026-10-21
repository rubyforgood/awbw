require "rails_helper"

RSpec.describe DripDate do
  let(:late_pacific_evening) { Time.utc(2026, 9, 11, 5) }

  describe ".label" do
    it "shows the date in the current viewer's zone, adding the time when it isn't their midnight" do
      Time.use_zone("Pacific Time (US & Canada)") { expect(described_class.label(late_pacific_evening)).to eq("September 10, 2026 at 10 PM PDT") }
      Time.use_zone("Eastern Time (US & Canada)") { expect(described_class.label(late_pacific_evening)).to eq("September 11, 2026 at 1 AM EDT") }
    end

    it "shows just the date at the viewer's midnight" do
      Time.use_zone("Eastern Time (US & Canada)") { expect(described_class.label(Time.zone.local(2026, 9, 10))).to eq("September 10, 2026") }
    end

    it "keeps the minutes only when there are some" do
      Time.use_zone("Pacific Time (US & Canada)") { expect(described_class.label(Time.zone.local(2026, 9, 10, 16, 30))).to eq("September 10, 2026 at 4:30 PM PDT") }
    end

    it "is nil without a date" do
      expect(described_class.label(nil)).to be_nil
    end
  end

  describe ".cast" do
    it "keeps the stored instant when the submitted date matches it in the editor's zone" do
      Time.use_zone("Pacific Time (US & Canada)") do
        expect(described_class.cast(late_pacific_evening, "2026-09-10")).to eq(late_pacific_evening)
      end
    end

    it "reads a changed date as midnight in the editor's zone" do
      Time.use_zone("Eastern Time (US & Canada)") do
        expect(described_class.cast(late_pacific_evening, "2026-09-12")).to eq(Time.zone.local(2026, 9, 12))
        expect(described_class.cast(nil, "2026-09-10")).to eq(Time.zone.local(2026, 9, 10))
      end
    end

    it "passes a datetime or a blank through for the attribute to parse" do
      expect(described_class.cast(late_pacific_evening, "2026-09-10T22:00")).to eq("2026-09-10T22:00")
      expect(described_class.cast(late_pacific_evening, "")).to eq("")
    end
  end
end
