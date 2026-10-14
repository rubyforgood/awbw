require "rails_helper"

RSpec.describe ProfileChangeRequestDecorator do
  describe "#requester_summary" do
    it "names the field and new value for an email request" do
      request = build_stubbed(:profile_change_request, :primary_email, requested_value: "new@example.com").decorate
      expect(request.requester_summary).to eq("Primary email: new@example.com")
    end

    it "quotes the details for an other request" do
      request = build_stubbed(:profile_change_request, :other, details: "Fix my last name").decorate
      expect(request.requester_summary).to eq("Profile data: Fix my last name")
    end

    it "names the change and organization for an affiliation request" do
      person = create(:person)
      affiliation = create(:affiliation, person: person, organization: create(:organization, name: "Sunrise Center"))
      request = build_stubbed(:profile_change_request, person: person, affiliation: affiliation,
                                                       requested_value: "Title or role").decorate

      expect(request.requester_summary).to eq("Title or role: Sunrise Center")
    end
  end

  describe "#heading" do
    it "titles the free-text request form as a profile data change" do
      expect(build_stubbed(:profile_change_request, :other).decorate.heading).to eq("Request a profile data change")
    end

    it "leaves the email form on the default title" do
      expect(build_stubbed(:profile_change_request, :primary_email).decorate.heading).to be_nil
    end

    it "titles an organization request by the chosen change" do
      request = build_stubbed(:profile_change_request, requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_DATES)
      expect(request.decorate.heading).to eq("Fix my start or end date")
    end
  end

  describe "#profile_return_path" do
    it "returns to the profile's affiliations for an affiliation request" do
      request = build_stubbed(:profile_change_request).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}#affiliations")
    end

    it "returns to the email card on the edit page when it came from there" do
      request = build_stubbed(:profile_change_request, :secondary_email).decorate
      expect(request.profile_return_path("details")).to eq("/people/#{request.person.to_param}/details#emails")
    end

    it "returns to the top of the profile for an email request" do
      request = build_stubbed(:profile_change_request, :primary_email).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}")
    end
  end
end
