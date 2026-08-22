require "rails_helper"

RSpec.describe "Owner view of affiliations on the person edit form", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:organization) { create(:organization, name: "Sunrise Center") }

  before do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: Date.new(2018, 1, 1),
                         end_date: Date.new(2020, 6, 1), inactive: true)
    sign_in owner_user
  end

  it "lists the owner's affiliations with dates, status, and a contact-us request link" do
    get edit_person_path(person)

    expect(response).to be_successful
    expect(response.body).to include("Sunrise Center")
    expect(response.body).to include("Jan 2018 – Jun 2020")
    expect(response.body).to include("Inactive")
    expect(response.body).to include("Contact us to request a change")
    expect(response.body).to include("return_to=person_edit")
  end
end
