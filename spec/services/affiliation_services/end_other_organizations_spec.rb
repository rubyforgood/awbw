require "rails_helper"

RSpec.describe AffiliationServices::EndOtherOrganizations do
  let(:person) { create(:person) }
  let(:new_org) { create(:organization) }

  it "ends active rows at other organizations the day before and spares the new one" do
    elsewhere = create(:affiliation, person: person, start_date: 1.year.ago, end_date: nil)
    here = create(:affiliation, person: person, organization: new_org, start_date: 1.year.ago, end_date: nil)
    already_ended = create(:affiliation, person: person, start_date: 3.years.ago, end_date: 2.years.ago)

    ended = described_class.call(person:, organization: new_org, effective_date: Date.new(2026, 9, 1))

    expect(ended).to eq([ elsewhere ])
    expect(elsewhere.reload.end_date).to eq(Date.new(2026, 8, 31))
    expect(here.reload.end_date).to be_nil
    expect(already_ended.reload.end_date).to eq(2.years.ago.to_date)
  end

  it "ends only the organizations it's limited to" do
    left = create(:affiliation, person: person, start_date: 1.year.ago, end_date: nil)
    kept = create(:affiliation, person: person, start_date: 1.year.ago, end_date: nil)

    described_class.call(person:, organization: new_org, effective_date: Date.new(2026, 9, 1), only: [ left.organization_id ])

    expect(left.reload.end_date).to eq(Date.new(2026, 8, 31))
    expect(kept.reload.end_date).to be_nil
  end
end
