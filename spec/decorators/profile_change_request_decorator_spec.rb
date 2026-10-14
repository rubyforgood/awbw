require "rails_helper"

RSpec.describe ProfileChangeRequestDecorator do
  describe "#requester_summary" do
    it "names the field and new value for an email request" do
      request = build_stubbed(:profile_change_request, :primary_email, requested_value: "new@example.com").decorate
      expect(request.requester_summary).to eq("Primary email: new@example.com")
    end

    it "quotes the details for an other request" do
      request = build_stubbed(:profile_change_request, :other, details: "Fix my last name").decorate
      expect(request.requester_summary).to eq("Profile: Fix my last name")
    end

    it "names the change and organization for an affiliation request" do
      person = create(:person)
      affiliation = create(:affiliation, person: person, organization: create(:organization, name: "Sunrise Center"))
      request = build_stubbed(:profile_change_request, person: person, affiliation: affiliation,
                                                       requested_value: "Title or role").decorate

      expect(request.requester_summary).to eq("Title or role: Sunrise Center")
    end
  end

  describe "#profile_return_path" do
    it "returns to the profile's affiliations for an affiliation request" do
      request = build_stubbed(:profile_change_request).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}#affiliations")
    end

    it "returns to the top of the profile for an email request" do
      request = build_stubbed(:profile_change_request, :primary_email).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}")
    end
  end
end
