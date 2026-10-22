require "rails_helper"

RSpec.describe NotDuplicateFilter do
  let(:category_type) { create(:category_type) }
  let(:records) { create_list(:category, 3, category_type: category_type) }
  let(:group) { Dedupable::CandidateGroup.new(label: "dupes", records: records, reasons: [ "Same name" ]) }

  subject(:filtered) { described_class.new(Category).call([ group ]) }

  it "keeps groups with no pairs marked" do
    expect(filtered.map(&:records)).to eq([ records ])
  end

  it "drops a group once every pair is marked" do
    NotDuplicatePair.mark!(records)

    expect(filtered).to be_empty
  end

  it "drops a record marked against every other record in its group" do
    NotDuplicatePair.mark!([ records.first, records.second ])
    NotDuplicatePair.mark!([ records.first, records.third ])

    expect(filtered.map(&:records)).to eq([ [ records.second, records.third ] ])
    expect(filtered.first.reasons).to eq([ "Same name" ])
  end

  it "keeps records still linked through another record" do
    NotDuplicatePair.mark!([ records.first, records.second ])

    expect(filtered.map(&:records)).to eq([ records ])
  end

  it "ignores pairs marked for another model" do
    NotDuplicatePair.create!(record_type: "Sector", first_record_id: records.first.id, second_record_id: records.second.id)
    NotDuplicatePair.create!(record_type: "Sector", first_record_id: records.first.id, second_record_id: records.third.id)

    expect(filtered.map(&:records)).to eq([ records ])
  end
end
