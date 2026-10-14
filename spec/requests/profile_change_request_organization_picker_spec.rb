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

    it "opens the form on the chosen organization, with a way back to the list" do
      new_affiliation_request(affiliation_id: harbor.id)

      expect(response.body).to include("Board member @ Harbor House")
      expect(response.body).to include(%(<option selected="selected" value="#{harbor.id}">))
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

  it "goes straight to the form for someone with one organization" do
    new_affiliation_request

    expect(response.body).not_to include("Which organization?")
    expect(response.body).to include("Facilitator @ Sunrise Center")
    expect(response.body).to include(%(<option selected="selected" value="#{sunrise.id}">))
  end

  it "starts an add request from the add card" do
    new_affiliation_request(add: 1)

    expect(response.body).to include(%(<option selected="selected" value="#{ProfileChangeRequest::AFFILIATION_CHANGE_ADD}">))
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

    expect(response.body).to include("What should change?")
    expect(response.body).not_to include("Change affiliation details to")
  end
end
