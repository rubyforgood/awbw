require "rails_helper"

RSpec.describe ProfileChangeRequestsHelper, type: :helper do
  describe "#change_requests_return_link" do
    let(:person) { create(:person, first_name: "Dana", last_name: "Reed") }

    it "returns to the record whose inline change log linked in" do
      affiliation = create(:affiliation, person: person, title: "Facilitator")
      controller.params.merge!(return_to: "record", return_type: "Affiliation", return_id: affiliation.id)

      expect(helper.change_requests_return_link(person))
        .to eq([ edit_affiliation_path(affiliation), "Facilitator" ])
    end

    it "returns to the activity log filtered to the record the row was about" do
      controller.params.merge!(return_to: "activities", return_type: "Affiliation", return_id: 7)

      expect(helper.change_requests_return_link(person))
        .to eq([ admin_activities_events_path(resource_type: "Affiliation", resource_id: 7), "Activity log" ])
    end

    it "falls back to the person when the change log's record is gone" do
      controller.params.merge!(return_to: "record", return_type: "Affiliation", return_id: 0)

      expect(helper.change_requests_return_link(person)).to eq([ edit_person_path(person), "Dana Reed" ])
    end

    it "ignores a return_type that names something other than a model" do
      controller.params.merge!(return_to: "record", return_type: "Kernel", return_id: 1)

      expect(helper.change_requests_return_link(person)).to eq([ edit_person_path(person), "Dana Reed" ])
    end

    it "falls back to the person, then home, with no origin to return to" do
      expect(helper.change_requests_return_link(person)).to eq([ edit_person_path(person), "Dana Reed" ])
      expect(helper.change_requests_return_link(nil)).to eq([ root_path, "Home" ])
    end
  end
end
