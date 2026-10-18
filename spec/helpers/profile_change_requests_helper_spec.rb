require "rails_helper"

RSpec.describe ProfileChangeRequestsHelper, type: :helper do
  describe "#change_requests_return_link" do
    let(:person) { create(:person, first_name: "Dana", last_name: "Reed") }

    def returning_from(origin, record)
      event = create(:ahoy_event, resource_type: record.class.name, resource_id: record.id)
      controller.params.merge!(return_to: origin, return_activity: event.id)
    end

    it "returns to the record whose inline change log linked in" do
      affiliation = create(:affiliation, person: person, title: "Facilitator")
      returning_from("record", affiliation)

      expect(helper.change_requests_return_link(person))
        .to eq([ edit_affiliation_path(affiliation), "Facilitator" ])
    end

    it "returns to the activity log filtered to the record the row was about" do
      returning_from("activities", person)

      expect(helper.change_requests_return_link(person))
        .to eq([ admin_activities_events_path(resource_type: "Person", resource_id: person.id), "Activity log" ])
    end

    it "returns to the unfiltered activity log for a row with no record" do
      event = create(:ahoy_event, properties: {})
      controller.params.merge!(return_to: "activities", return_activity: event.id)

      expect(helper.change_requests_return_link(person)).to eq([ admin_activities_events_path, "Activity log" ])
    end

    it "falls back to the person when the change log's record is gone" do
      affiliation = create(:affiliation, person: person)
      returning_from("record", affiliation)
      affiliation.destroy!

      expect(helper.change_requests_return_link(person)).to eq([ edit_person_path(person), "Dana Reed" ])
    end

    it "falls back to the person, then home, with no origin to return to" do
      expect(helper.change_requests_return_link(person)).to eq([ edit_person_path(person), "Dana Reed" ])
      expect(helper.change_requests_return_link(nil)).to eq([ root_path, "Home" ])
    end
  end
end
