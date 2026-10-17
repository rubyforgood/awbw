require "rails_helper"

RSpec.describe "Choosing which organization to change", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let!(:sunrise) { create(:affiliation, person: person, organization: create(:organization, name: "Sunrise Center"), title: "Facilitator") }

  before { sign_in owner_user }

  def new_affiliation_request(**params)
    get new_profile_change_request_path(person_id: person, field: "affiliation", **params)
  end

  context "with several organizations" do
    let!(:harbor) { create(:affiliation, person: person, organization: create(:organization, name: "Harbor House"), title: "Board member") }

    it "lists each organization and a way to add one" do
      new_affiliation_request

      expect(response.body).to include("Which organization?")
      expect(response.body).to include("Sunrise Center", "Harbor House")
      expect(response.body).to include("affiliation_id=#{sunrise.id}", "affiliation_id=#{harbor.id}")
      expect(response.body).to include("Add an organization")
    end

    it "asks what to change on the chosen organization, with a way back to the list" do
      new_affiliation_request(affiliation_id: harbor.id)

      expect(response.body).to include("What would you like to change?")
      expect(response.body).to include("Board member @ Harbor House")
      expect(response.body).to include("Fix my start or end date")
      expect(response.body).to include("Back to my organizations")
    end

    it "links an organization with a pending request to that request" do
      pending_request = create(:profile_change_request, person: person, affiliation: harbor,
                                                        requested_value: "Title or role", proposed_title: "Chair", details: nil)

      new_affiliation_request

      expect(response.body).to include(edit_profile_change_request_path(pending_request))
    end

    it "sends a chosen organization with a pending request to that request" do
      pending_request = create(:profile_change_request, person: person, affiliation: harbor,
                                                        requested_value: "Title or role", proposed_title: "Chair", details: nil)

      new_affiliation_request(affiliation_id: harbor.id)

      expect(response).to redirect_to(edit_profile_change_request_path(pending_request))
    end
  end

  it "skips the organization list for someone with one organization" do
    new_affiliation_request

    expect(response.body).not_to include("Which organization?")
    expect(response.body).to include("What would you like to change?")
    expect(response.body).to include("AWBW Facilitator @ Sunrise Center")
  end

  it "shows only date pickers for a date change, without a show-hide dropdown" do
    new_affiliation_request(affiliation_id: sunrise.id, change: ProfileChangeRequest::AFFILIATION_CHANGE_DATES)

    expect(response.body).to include("Fix my start or end date")
    expect(response.body).to include('type="date" name="profile_change_request[proposed_start_date]"')
    expect(response.body).to include('type="date" name="profile_change_request[proposed_end_date]"')
    expect(response.body).not_to include("conditional-fields")
    expect(response.body).not_to include("profile_change_request[proposed_title]")
  end

  it "shows only the title box for a title change" do
    new_affiliation_request(affiliation_id: sunrise.id, change: ProfileChangeRequest::AFFILIATION_CHANGE_TITLE)

    expect(response.body).to include("profile_change_request[proposed_title]")
    expect(response.body).to include("Right now: AWBW Facilitator")
    expect(response.body).not_to include("profile_change_request[proposed_start_date]")
  end

  it "offers changing a work address alongside adding one" do
    new_affiliation_request(affiliation_id: sunrise.id)

    expect(response.body).to include("Change my work address", "Add my work address")
  end

  it "shows the current work address on a work address change" do
    address = create(:address, addressable: sunrise.organization, street_address: "12 Elm St", city: "Reno", state: "NV", zip_code: "89501")
    sunrise.update!(organization_address: address)

    new_affiliation_request(affiliation_id: sunrise.id, change: ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS)

    expect(response.body).to include("Right now:", "12 Elm St, Reno, NV 89501")
    expect(response.body).to include("Your new work address")
  end

  it "saves a date change sent from the focused form" do
    post profile_change_requests_path(person_id: person), params: {
      profile_change_request: {
        field: "affiliation", affiliation_id: sunrise.id,
        requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_DATES, proposed_end_date: "2026-06-30"
      }
    }

    expect(response).to redirect_to(edit_person_path(person, anchor: "affiliations"))
    expect(person.profile_change_requests.last).to have_attributes(affiliation: sunrise, proposed_end_date: Date.new(2026, 6, 30))
  end

  it "sends an add request for an organization that isn't listed" do
    new_affiliation_request(add: 1)
    expect(response.body).to include("Not on the list? Type the organization")

    post profile_change_requests_path(person_id: person), params: {
      profile_change_request: {
        field: "affiliation", requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_ADD,
        proposed_organization_name: "Hillside Shelter", proposed_title: "Counselor"
      }
    }

    expect(person.profile_change_requests.last).to have_attributes(proposed_organization_name: "Hillside Shelter", organization_id: nil)
  end

  it "starts an add request from the add card" do
    new_affiliation_request(add: 1)

    expect(response.body).to include("Add an organization")
    expect(response.body).to include(%(value="#{ProfileChangeRequest::AFFILIATION_CHANGE_ADD}"))
    expect(response.body).to include("profile_change_request[organization_id]")
  end
end

RSpec.describe "Editing a pending organization request", type: :request do
  it "shows the organization form, not a plain text box" do
    owner_user = create(:user, :with_person)
    affiliation = create(:affiliation, person: owner_user.person, organization: create(:organization))
    request = create(:profile_change_request, person: owner_user.person, requested_by: owner_user, affiliation: affiliation,
                                              requested_value: "Title or role", proposed_title: "Lead", details: nil)
    sign_in owner_user

    get edit_profile_change_request_path(request)

    expect(response.body).to include("profile_change_request[proposed_title]")
    expect(response.body).not_to include("Change affiliation details to")
  end
end
