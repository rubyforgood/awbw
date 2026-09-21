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

    it "submits a structured affiliation change targeting a specific affiliation" do
      org = create(:organization, name: "Sunrise Center")
      affiliation = create(:affiliation, person: person, organization: org, title: "Facilitator")

      expect {
        post profile_change_requests_path(person_id: person), params: {
          profile_change_request: {
            field: "affiliation",
            affiliation_id: affiliation.id,
            requested_value: "Start or end dates",
            details: "End date should be June 2020."
          }
        }
      }.to change(ProfileChangeRequest, :count).by(1)

      request = ProfileChangeRequest.last
      expect(request.affiliation).to eq(affiliation)
      expect(request.requested_value).to eq("Start or end dates")
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

    it "renders the queue shell with the results frame" do
      get profile_change_requests_path

      expect(response).to be_successful
      expect(response.body).to include("Changes requested")
      expect(response.body).to include("profile_change_requests_results")
    end

    it "lists requests in the results frame" do
      create(:profile_change_request, person: person, details: "please fix my dates")

      get profile_change_requests_path, headers: { "Turbo-Frame" => "profile_change_requests_results" }

      expect(response).to be_successful
      expect(response.body).to include("profile_change_requests_results")
      expect(response.body).to include("please fix my dates")
    end
  end

  describe "editing and de-duplicating a pending request" do
    before { sign_in owner_user }

    it "opens the existing pending request instead of creating a duplicate (single-target field)" do
      existing = create(:profile_change_request, :primary_email, person: person)

      get new_profile_change_request_path(person_id: person, field: "primary_email")

      expect(response).to redirect_to(edit_profile_change_request_path(existing))
    end

    it "lets the owner update their pending request" do
      request = create(:profile_change_request, person: person, field: "affiliation", details: "old")

      patch profile_change_request_path(request), params: {
        profile_change_request: { details: "new details" }
      }

      expect(request.reload.details).to eq("new details")
    end

    it "rejects a second pending request for the same target" do
      create(:profile_change_request, :primary_email, person: person)

      second = build(:profile_change_request, :primary_email, person: person)
      expect(second).not_to be_valid
    end
  end

  describe "review notifications and guards" do
    include ActiveJob::TestHelper
    before { sign_in admin }

    it "notifies the requester when a request is declined" do
      request = create(:profile_change_request, person: person, requested_by: owner_user)

      perform_enqueued_jobs do
        post decline_profile_change_request_path(request), params: { reviewer_note: "Not enough detail" }
      end

      expect(request.reload.reviewer_note).to eq("Not enough detail")
      expect(Notification.where(kind: "profile_change_reviewed")).to exist
    end

    it "does not overwrite an email already in use by another account" do
      create(:user, email: "taken@example.com")
      request = create(:profile_change_request, :primary_email, person: person, requested_value: "taken@example.com")

      post approve_profile_change_request_path(request)

      expect(request.reload).to be_pending
      expect(person.user.reload.unconfirmed_email).to be_blank
    end

    it "resolves without re-sending when the email already matches" do
      request = create(:profile_change_request, :primary_email, person: person, requested_value: person.user.email)

      post approve_profile_change_request_path(request)

      expect(request.reload).to be_resolved
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
