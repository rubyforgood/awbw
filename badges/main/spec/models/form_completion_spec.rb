require "rails_helper"

RSpec.describe FormCompletion do
  let(:person) { create(:person) }
  let(:form) { create(:form, anonymous: true) }
  let(:event) { create(:event) }

  describe "validations" do
    it "allows one completion per person, form, and event" do
      create(:form_completion, person:, form:, event:)

      duplicate = build(:form_completion, person:, form:, event:)
      expect(duplicate).not_to be_valid
      expect(build(:form_completion, person:, form:, event: create(:event))).to be_valid
    end
  end

  describe ".record!" do
    it "stamps today's date" do
      travel_to Time.zone.local(2026, 10, 19, 15, 42) do
        completion = described_class.record!(person:, form:, event:)

        expect(completion.completed_on).to eq(Date.new(2026, 10, 19))
      end
    end

    it "is idempotent" do
      described_class.record!(person:, form:, event:)

      expect { described_class.record!(person:, form:, event:) }.not_to change(described_class, :count)
    end
  end

  # Only a date is kept: a time of day (or a link) would let staff line a
  # completion up with the anonymous submission it came from.
  it "keeps no submission link or time of day" do
    expect(described_class.column_names).not_to include("form_submission_id", "created_at", "updated_at")
    expect(described_class.columns_hash["completed_on"].type).to eq(:date)
  end
end
