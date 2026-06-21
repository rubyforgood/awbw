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
  end
end
