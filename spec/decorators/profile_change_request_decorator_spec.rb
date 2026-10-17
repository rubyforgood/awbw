require "rails_helper"

RSpec.describe ProfileChangeRequestDecorator do
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
    it "returns to the affiliations card on the edit page for an affiliation request" do
      request = build_stubbed(:profile_change_request).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}/edit#affiliations")
    end

    it "returns to the emails card for an email request" do
      request = build_stubbed(:profile_change_request, :secondary_email).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}/edit#emails")
    end

    it "returns to the top of the edit page for an other request" do
      request = build_stubbed(:profile_change_request, :other).decorate
      expect(request.profile_return_path).to eq("/people/#{request.person.to_param}/edit")
    end
  end

  describe "review confirm prompts" do
    let(:requester) { build_stubbed(:user, email: "requester@example.com") }
    let(:request) { build_stubbed(:profile_change_request, :other, requested_by: requester).decorate }

    it "tells the admin approving that the requester gets an email" do
      expect(request.approve_confirm).to eq("Approve and apply this change now? This emails #{requester.full_name} (requester@example.com).")
    end

    it "tells the admin resolving that the requester gets an email with the note" do
      expect(request.resolve_confirm).to eq("Mark this request as resolved? This emails #{requester.full_name} (requester@example.com), including your note.")
    end

    it "tells the admin declining that the requester gets an email with the note" do
      expect(request.decline_confirm).to eq("Decline this request? This emails #{requester.full_name} (requester@example.com), including your note.")
    end

    it "skips the email notice when the requester has no email" do
      request = build_stubbed(:profile_change_request, :other, requested_by: nil).decorate
      expect(request.decline_confirm).to eq("Decline this request?")
    end
  end
end
