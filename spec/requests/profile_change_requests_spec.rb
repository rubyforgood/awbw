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

    it "asks about a locked license and returns to the licenses card" do
      license = create(:professional_license, person: person)

      get new_profile_change_request_path(person_id: person, field: "professional_license", professional_license_id: license.id)
      expect(response.body).to include("Request a license change")

      post profile_change_requests_path(person_id: person), params: {
        profile_change_request: { field: "professional_license", professional_license_id: license.id, details: "The number is 12345" }
      }

      expect(response).to redirect_to(edit_person_path(person, anchor: "professional-licenses"))
      expect(person.profile_change_requests.last).to have_attributes(professional_license: license, details: "The number is 12345")
    end

    it "can't ask about someone else's license" do
      get new_profile_change_request_path(person_id: person, field: "professional_license", professional_license_id: create(:professional_license).id)

      expect(response).to have_http_status(:not_found)
    end

    it "submits a structured affiliation date change targeting a specific affiliation" do
      org = create(:organization, name: "Sunrise Center")
      affiliation = create(:affiliation, person: person, organization: org, title: "Facilitator")

      expect {
        post profile_change_requests_path(person_id: person), params: {
          profile_change_request: {
            field: "affiliation",
            affiliation_id: affiliation.id,
            requested_value: "Start or end dates",
            proposed_end_date: "2020-06-01"
          }
        }
      }.to change(ProfileChangeRequest, :count).by(1)

      request = ProfileChangeRequest.last
      expect(request.affiliation).to eq(affiliation)
      expect(request.proposed_end_date).to eq(Date.new(2020, 6, 1))
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

    it "approves a type-only primary email change without sending a confirmation" do
      person.update!(email_type: "work")
      request = create(:profile_change_request, :primary_email, person: person,
                                                                requested_value: person.user.email, proposed_email_type: "personal")

      post approve_profile_change_request_path(request)

      expect(request.reload).to be_resolved
      expect(person.reload.email_type).to eq("personal")
      expect(person.user.reload.unconfirmed_email).to be_blank
    end

    it "carries the type onto the login when the primary address changes" do
      request = create(:profile_change_request, :primary_email, person: person,
                                                                requested_value: "changed@example.com", proposed_email_type: "personal")

      post approve_profile_change_request_path(request)

      expect(person.reload.email_type).to eq("personal")
      expect(person.user.reload).to have_attributes(unconfirmed_email: "changed@example.com", email_type: "personal")
    end

    it "approves a secondary email request with its type" do
      request = create(:profile_change_request, :secondary_email, person: person,
                                                                  requested_value: "second@example.com", proposed_email_type: "work")

      post approve_profile_change_request_path(request)

      expect(person.reload).to have_attributes(email_2: "second@example.com", email_2_type: "work")
    end

    it "approves a secondary email request by setting email_2" do
      request = create(:profile_change_request, :secondary_email, person: person, requested_value: "second@example.com")

      post approve_profile_change_request_path(request)

      expect(request.reload).to be_resolved
      expect(person.reload.email_2).to eq("second@example.com")
    end

    it "puts a change-requests button on the person's edit page, filtered to them" do
      create(:profile_change_request, :primary_email, person: person)

      get edit_person_path(person)

      expect(response.body).to include(ERB::Util.html_escape(profile_change_requests_path(person_id: person.id, status: "pending")))
      expect(response.body).to include("Change requests (1 pending)")
    end

    it "points the button at the latest status when nothing is pending" do
      create(:profile_change_request, :primary_email, :resolved, person: person)

      get edit_person_path(person)

      expect(response.body).to include(ERB::Util.html_escape(profile_change_requests_path(person_id: person.id, status: "resolved")))
    end

    it "leaves the button off when the person has no requests" do
      get edit_person_path(person)

      expect(response.body).not_to include("Change requests")
    end

    it "filters the queue to one person" do
      create(:profile_change_request, :primary_email, person: person, requested_value: "mine@example.com")
      create(:profile_change_request, :primary_email, requested_value: "someone-else@example.com")

      get profile_change_requests_path(status: "pending", person_id: person.id), headers: { "Turbo-Frame" => "profile_change_requests_results" }

      expect(response.body).to include("mine@example.com")
      expect(response.body).not_to include("someone-else@example.com")
      expect(response.body).to include("person_id=#{person.id}")
    end

    it "links back to the person on a filtered queue" do
      get profile_change_requests_path(person_id: person.id)

      expect(response.body).to include(edit_person_path(person))
      expect(response.body).to include("Show everyone")
    end

    it "offers no Approve for an organization that isn't in the portal yet" do
      create(:profile_change_request, person: person, requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_ADD,
                                      proposed_organization_name: "Hillside Shelter", proposed_title: "Counselor", details: nil)

      get profile_change_requests_path(status: "pending"), headers: { "Turbo-Frame" => "profile_change_requests_results" }

      expect(response.body).to include("Hillside Shelter (not in the portal yet)")
      expect(response.body).not_to include(">Approve<")
    end

    it "approves an organization name request by renaming the org" do
      org = create(:organization, name: "Old Name")
      create(:affiliation, person: person, organization: org, inactive: false, start_date: 1.year.ago, end_date: nil)
      request = create(:profile_change_request, :organization_name, person: person, requested_value: "New Name")

      post approve_profile_change_request_path(request)

      expect(org.reload.name).to eq("New Name")
      expect(request.reload).to be_resolved
    end

    it "approves an affiliation title change by updating the affiliation" do
      affiliation = create(:affiliation, person: person, title: "Facilitator")
      request = create(:profile_change_request, person: person, field: "affiliation",
                       requested_value: "Title or role", affiliation: affiliation,
                       proposed_title: "Lead Facilitator", details: nil)

      post approve_profile_change_request_path(request)

      expect(affiliation.reload.title).to eq("Lead Facilitator")
      expect(request.reload).to be_resolved
    end

    it "approves a work address change picked from the org's list by setting it" do
      affiliation = create(:affiliation, person: person)
      address = create(:address, addressable: affiliation.organization)
      request = create(:profile_change_request, person: person, affiliation: affiliation,
                       requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS,
                       proposed_organization_address: address, details: nil)

      get profile_change_requests_path(status: "pending"), headers: { "Turbo-Frame" => "profile_change_requests_results" }
      expect(response.body).to include(ERB::Util.html_escape(address.name), ">Approve<")

      post approve_profile_change_request_path(request)

      expect(affiliation.reload.organization_address).to eq(address)
      expect(request.reload).to be_resolved
    end

    it "approves a typed work address by adding it to the organization" do
      affiliation = create(:affiliation, person: person)
      request = create(:profile_change_request, person: person, affiliation: affiliation, details: nil,
                       requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS,
                       proposed_street_address: "12 Elm St", proposed_city: "Reno", proposed_state: "NV", proposed_zip_code: "89501")

      expect {
        post approve_profile_change_request_path(request)
      }.to change { affiliation.organization.addresses.count }.by(1)

      expect(affiliation.reload.organization_address).to have_attributes(street_address: "12 Elm St", city: "Reno", address_type: "work")
      expect(request.reload).to be_resolved
    end

    it "reuses the organization's matching address when approving a typed one" do
      affiliation = create(:affiliation, person: person)
      existing = create(:address, addressable: affiliation.organization, street_address: "12 Elm Street", city: "Reno", state: "NV")
      request = create(:profile_change_request, person: person, affiliation: affiliation, details: nil,
                       requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS,
                       proposed_street_address: "12 Elm St", proposed_city: "Reno", proposed_state: "NV")

      expect {
        post approve_profile_change_request_path(request)
      }.not_to change(Address, :count)

      expect(affiliation.reload.organization_address).to eq(existing)
    end

    it "approves an add-a-new-affiliation request by creating it" do
      org = create(:organization, name: "New Org")
      request = create(:profile_change_request, person: person, field: "affiliation",
                       requested_value: "Add a new affiliation", organization: org,
                       proposed_title: "Facilitator", proposed_start_date: "2026-01-01", details: nil)

      expect {
        post approve_profile_change_request_path(request)
      }.to change { person.affiliations.count }.by(1)

      expect(request.reload).to be_resolved
      expect(person.affiliations.exists?(organization: org, title: "Facilitator")).to be(true)
    end

    it "responds to a turbo_stream request by replacing the row and flash" do
      request = create(:profile_change_request, person: person)

      post resolve_profile_change_request_path(request),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include("profile_change_request_#{request.id}")
      expect(response.body).to include("flash_now")
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
      request = create(:profile_change_request, :primary_email, person: person, requested_value: "already@example.com")
      person.user.update_column(:email, "already@example.com")

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
