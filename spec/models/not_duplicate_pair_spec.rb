require "rails_helper"

RSpec.describe NotDuplicatePair do
  let(:category_type) { create(:category_type) }
  let!(:first) { create(:category, category_type: category_type) }
  let!(:second) { create(:category, category_type: category_type) }
  let!(:third) { create(:category, category_type: category_type) }

  it "requires the lower id first" do
    pair = build(:not_duplicate_pair, first_record_id: 5, second_record_id: 3)

    expect(pair).not_to be_valid
  end

  describe ".mark!" do
    it "records every pair in the group, lowest id first" do
      described_class.mark!([ third, first, second ])

      expect(described_class.for_model(Category).pluck(:first_record_id, :second_record_id)).to contain_exactly(
        [ first.id, second.id ], [ first.id, third.id ], [ second.id, third.id ]
      )
    end

    it "is idempotent" do
      described_class.mark!([ first, second ])

      expect { described_class.mark!([ second, first ]) }.not_to change(described_class, :count)
    end
  end

  describe ".marked" do
    it "lists each pair with its records, skipping pairs whose record is gone" do
      described_class.mark!([ first, second ])
      described_class.create!(record_type: "Category", first_record_id: third.id, second_record_id: third.id + 1_000)

      expect(described_class.marked(Category).map(&:records)).to eq([ [ first, second ] ])
    end
  end

  describe ".transfer!" do
    it "carries the merged-away record's pairs over to the keeper" do
      described_class.mark!([ second, third ])

      described_class.transfer!(from: second, to: first)

      expect(described_class.for_model(Category).pluck(:first_record_id, :second_record_id)).to eq([ [ first.id, third.id ] ])
    end

    it "drops a pair between the keeper and the merged-away record" do
      described_class.mark!([ first, second ])

      described_class.transfer!(from: second, to: first)

      expect(described_class.count).to eq(0)
    end
  end
end
