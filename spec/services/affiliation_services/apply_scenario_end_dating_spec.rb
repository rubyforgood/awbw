require "rails_helper"

RSpec.describe AffiliationServices::ApplyScenarioEndDating do
  let(:person) { create(:person, user: nil) }
  let(:new_org) { create(:organization, name: "New Org") }
  let(:old_org) { create(:organization, name: "Old Org") }
  let(:effective_date) { Date.new(2026, 8, 14) }

  def call_with(purpose)
    described_class.call(person: person, organization: new_org, scenario: purpose, effective_date: effective_date)
  end

  describe "new job" do
    it "ends the person's active job and facilitator affiliations at other orgs, the day before, and returns them" do
      job = create(:affiliation, person: person, organization: old_org, title: "Counselor")
      facilitator = create(:affiliation, person: person, organization: old_org, title: "Facilitator")

      ended = call_with("new_job")

      expect(job.reload.end_date).to eq(effective_date - 1.day)
      expect(facilitator.reload.end_date).to eq(effective_date - 1.day)
      expect(job.inactive).to be(true)
      expect(ended).to contain_exactly(job, facilitator)
    end

    it "spares the linked org's own affiliations and already-ended rows" do
      at_new_org = create(:affiliation, person: person, organization: new_org, title: "Facilitator")
      long_gone = create(:affiliation, person: person, organization: old_org, title: "Facilitator",
                         end_date: Date.new(2024, 1, 31))

      call_with("new_job")

      expect(at_new_org.reload.end_date).to be_nil
      expect(long_gone.reload.end_date).to eq(Date.new(2024, 1, 31))
    end
  end

  describe "every other scenario" do
    it "ends nothing — reinstatement reconciles registration-style" do
      facilitator = create(:affiliation, person: person, organization: old_org, title: "Facilitator")

      call_with("reinstatement")
      call_with("on_demand")
      call_with(nil)

      expect(facilitator.reload.end_date).to be_nil
    end
  end
end
