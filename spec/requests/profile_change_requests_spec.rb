require "rails_helper"

RSpec.describe "Profile change requests", type: :request do
  let(:owner_user) { create(:user, :with_person, email: "owner@example.com") }
  let(:person) { owner_user.person }
  let(:admin) { create(:user, :admin) }

  describe "owner submits a request" do
    include ActiveJob::TestHelper

    before { sign_in owner_user }

    it "creates the request and emails admins and the submitter" do
      expect {
        perform_enqueued_jobs do
          post profile_change_requests_path(person_id: person), params: {
            profile_change_request: { field: "primary_email", requested_value: "new@example.com" }
          }
        end
      }.to change(ProfileChangeRequest, :count).by(1)

      request = ProfileChangeRequest.last
      expect(request.person).to eq(person)
      expect(request.requested_by).to eq(owner_user)
      expect(Notification.where(kind: "profile_change_requested_fyi")).to exist
      subjects = ActionMailer::Base.deliveries.map(&:subject).join(" ")
      expect(subjects).to include("requested a change")
    end

    it "forbids submitting for someone else" do
      stranger = create(:person, user: nil)
      post profile_change_requests_path(person_id: stranger), params: {
        profile_change_request: { field: "affiliation", details: "not mine" }
      }
      expect(response).to redirect_to(root_path)
      expect(ProfileChangeRequest.count).to eq(0)
    end
  end

  describe "admin review actions" do
    before { sign_in admin }

    it "approves a primary email request and starts the confirmation flow" do
      request = create(:profile_change_request, :primary_email, person: person, requested_value: "changed@example.com")

      post approve_profile_change_request_path(request)

      expect(request.reload).to be_resolved
      expect(request.resolution_method).to eq("approved")
      expect(person.user.reload.unconfirmed_email).to eq("changed@example.com")
    end

    it "approves an organization name request by renaming the org" do
      org = create(:organization, name: "Old Name")
      create(:affiliation, person: person, organization: org, inactive: false, start_date: 1.year.ago, end_date: nil)
      request = create(:profile_change_request, :organization_name, person: person, requested_value: "New Name")

      post approve_profile_change_request_path(request)

      expect(org.reload.name).to eq("New Name")
      expect(request.reload).to be_resolved
    end

    it "marks a request resolved manually" do
      request = create(:profile_change_request, person: person)

      post resolve_profile_change_request_path(request)

      expect(request.reload).to be_resolved
      expect(request.resolution_method).to eq("manual")
    end

    it "declines a request" do
      request = create(:profile_change_request, person: person)

      post decline_profile_change_request_path(request)

      expect(request.reload).to be_declined
    end

    it "lists requests on the queue page" do
      create(:profile_change_request, person: person, details: "please fix my dates")

      get profile_change_requests_path

      expect(response).to be_successful
      expect(response.body).to include("Changes requested")
      expect(response.body).to include("please fix my dates")
    end
  end

  describe "authorization" do
    it "forbids a non-admin from approving" do
      request = create(:profile_change_request, :primary_email, person: person)
      sign_in owner_user

      post approve_profile_change_request_path(request)

      expect(response).to redirect_to(root_path)
      expect(request.reload).to be_pending
    end
  end
end
