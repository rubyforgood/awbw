require "rails_helper"

RSpec.describe ProfileChangeRequestDecorator do
  describe "#pending_summary" do
    it "names a new email" do
      request = build_stubbed(:profile_change_request, :secondary_email, requested_value: "new@example.com", proposed_email_type: nil)
      expect(request.decorate.pending_summary).to eq("New secondary email: new@example.com")
    end

    it "names an organization change in plain words" do
      organization = build_stubbed(:organization, name: "Riverside Center")
      request = build_stubbed(:profile_change_request, requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_ADD, organization: organization)
      expect(request.decorate.pending_summary).to eq("Add organization: Riverside Center")
    end

    it "falls back to a general label for an organization change it doesn't name" do
      expect(build_stubbed(:profile_change_request, requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_OTHER).decorate.pending_summary)
        .to start_with("Organization change")
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

    it "tells the admin approving that the requester gets an email with the note" do
      expect(request.approve_confirm).to eq("Approve and apply this change now? This emails #{requester.full_name} (requester@example.com), including your note.")
    end

    it "tells the admin resolving that the requester gets an email with the note" do
      expect(request.resolve_confirm).to eq("Mark this request as resolved? This emails #{requester.full_name} (requester@example.com), including your note.")
    end

    it "tells the admin declining that the requester gets an email with the note" do
      expect(request.decline_confirm).to eq("Decline this request? This emails #{requester.full_name} (requester@example.com), including your note.")
    end

    it "names who gets emailed for the email preview" do
      expect(request.review_email_recipient).to eq("#{requester.full_name} <requester@example.com>")
    end

    it "skips the email notice when the requester has no email" do
      request = build_stubbed(:profile_change_request, :other, requested_by: nil).decorate
      expect(request.decline_confirm).to eq("Decline this request?")
      expect(request.review_email_recipient).to be_nil
    end
  end

  describe "#review_outcome" do
    it "says approved for an auto-applied request" do
      expect(build_stubbed(:profile_change_request, status: "resolved", resolution_method: "approved").decorate.review_outcome).to eq("approved")
    end

    it "says resolved for a manually resolved request" do
      expect(build_stubbed(:profile_change_request, status: "resolved", resolution_method: "manual").decorate.review_outcome).to eq("resolved")
    end

    it "says declined for a declined request" do
      expect(build_stubbed(:profile_change_request, status: "declined").decorate.review_outcome).to eq("declined")
    end
  end

  describe "#email_greeting" do
    it "greets the requester by first name" do
      requester = build_stubbed(:user, person: build_stubbed(:person, first_name: "Amy"))
      expect(build_stubbed(:profile_change_request, requested_by: requester).decorate.email_greeting).to eq("Dear Amy,")
    end
  end

  describe "#requested_change" do
    it "names the new email" do
      request = build_stubbed(:profile_change_request, :secondary_email, requested_value: "new@example.com", proposed_email_type: nil)
      expect(request.decorate.requested_change).to eq("change your secondary email to new@example.com")
    end

    it "names the new organization name" do
      request = build_stubbed(:profile_change_request, field: "organization_name", requested_value: "Riverside Center")
      expect(request.decorate.requested_change).to eq("change your organization name to Riverside Center")
    end

    it "names the old login for a primary email, which Devise keeps until confirmation" do
      person = build_stubbed(:person, email_type: nil, user: build_stubbed(:user, email: "old@example.com", email_type: nil))
      request = build_stubbed(:profile_change_request, :primary_email, person: person, status: "resolved", proposed_email_type: nil)
      expect(request.decorate.requested_change).to eq("change your primary email from old@example.com to new@example.com")
    end

    it "names the old value for a declined request, which changed nothing" do
      person = build_stubbed(:person, email_2: "old2@example.com", email_2_type: nil)
      request = build_stubbed(:profile_change_request, :secondary_email, person: person, status: "declined", proposed_email_type: nil)
      expect(request.decorate.requested_change).to eq("change your secondary email from old2@example.com to second@example.com")
    end

    it "leaves out the old value once an applied change has overwritten it" do
      person = build_stubbed(:person, email_2: "second@example.com", email_2_type: nil)
      request = build_stubbed(:profile_change_request, :secondary_email, person: person, status: "resolved", proposed_email_type: nil)
      expect(request.decorate.requested_change).to eq("change your secondary email to second@example.com")
    end

    it "falls back to the topic for free-text requests" do
      expect(build_stubbed(:profile_change_request, :other).decorate.requested_change).to eq("update your profile data")
    end
  end
end
