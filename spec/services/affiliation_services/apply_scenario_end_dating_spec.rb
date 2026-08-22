require "rails_helper"

RSpec.describe AffiliationServices::ApplyScenarioEndDating do
  let(:person) { create(:person, user: nil) }
  let(:new_org) { create(:organization, name: "New Org") }
  let(:old_org) { create(:organization, name: "Old Org") }
  let(:effective_date) { Date.new(2026, 8, 14) }

  def call_with(purpose)
    described_class.call(person: person, organization: new_org, purpose: purpose, effective_date: effective_date)
  end

  describe "job change" do
    it "ends the person's active job and facilitator affiliations at other orgs, the day before, and returns them" do
      job = create(:affiliation, person: person, organization: old_org, title: "Counselor")
      facilitator = create(:affiliation, person: person, organization: old_org, title: "Facilitator")

      ended = call_with("job_change_agreement")

      expect(job.reload.end_date).to eq(effective_date - 1.day)
      expect(facilitator.reload.end_date).to eq(effective_date - 1.day)
      expect(job.inactive).to be(true)
      expect(ended).to contain_exactly(job, facilitator)
    end

    it "spares the linked org's own affiliations and already-ended rows" do
      at_new_org = create(:affiliation, person: person, organization: new_org, title: "Facilitator")
      long_gone = create(:affiliation, person: person, organization: old_org, title: "Facilitator",
                         end_date: Date.new(2024, 1, 31))

      call_with("job_change_agreement")

      expect(at_new_org.reload.end_date).to be_nil
      expect(long_gone.reload.end_date).to eq(Date.new(2024, 1, 31))
    end
  end

  describe "reinstatement" do
    it "ends active Facilitator affiliations everywhere but leaves job affiliations alone" do
      stale_facilitator = create(:affiliation, person: person, organization: old_org, title: "Facilitator")
      same_org_facilitator = create(:affiliation, person: person, organization: new_org, title: "Facilitator")
      job = create(:affiliation, person: person, organization: old_org, title: "Counselor")

      call_with("reinstatement_agreement")

      expect(stale_facilitator.reload.end_date).to eq(effective_date - 1.day)
      expect(same_org_facilitator.reload.end_date).to eq(effective_date - 1.day)
      expect(job.reload.end_date).to be_nil
    end
  end

  describe "on-demand and no scenario" do
    it "ends nothing" do
      facilitator = create(:affiliation, person: person, organization: old_org, title: "Facilitator")

      call_with("on_demand_agreement")
      call_with(nil)

      expect(facilitator.reload.end_date).to be_nil
    end
  end
end
