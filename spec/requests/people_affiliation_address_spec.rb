require "rails_helper"

RSpec.describe "People affiliation address picker", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /people/:id/edit" do
    it "renders the affiliation editor when the org has an address" do
      person = create(:person)
      organization = create(:organization)
      create(:address, addressable: organization)
      create(:affiliation, person: person, organization: organization)

      get edit_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Address")
    end

    it "still lists a linked address that is inactive, marked [INACTIVE]" do
      person = create(:person)
      organization = create(:organization)
      address = create(:address, addressable: organization, inactive: true, street_address: "123 Sesame Street")
      create(:affiliation, person: person, organization: organization, organization_address: address)

      get edit_person_path(person)

      expect(response.body).to include("[INACTIVE]")
      expect(response.body).to include("123 Sesame Street")
    end

    it "shows a comment indicator with the latest comment for an affiliation that has comments" do
      person = create(:person)
      organization = create(:organization)
      affiliation = create(:affiliation, person: person, organization: organization)
      create(:comment, commentable: affiliation, body: "Older note", created_at: 2.days.ago)
      create(:comment, commentable: affiliation, body: "Reviewed the paperwork", created_at: 1.hour.ago)

      get edit_person_path(person)

      expect(response.body).to include("fa-comment")
      expect(response.body).to include("2 comments")
      expect(response.body).to include("Reviewed the paperwork")
    end
  end
end
