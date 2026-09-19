require "rails_helper"

# The read-only owner view of affiliations on the person edit form is staged
# behind the profile-launch policy flip: PersonPolicy#edit? is admin-only for
# now and goes to admin || owner at launch. These specs simulate that flip to
# exercise the owner branch that lights up then.
RSpec.describe "Owner view of affiliations on the person edit form", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:organization) { create(:organization, name: "Sunrise Center") }

  before do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: Date.new(2018, 1, 1),
                         end_date: Date.new(2020, 6, 1), inactive: true)
    sign_in owner_user
    allow_any_instance_of(PersonPolicy).to receive(:edit?).and_return(true)
  end

  it "lists the owner's affiliations with dates, status, and change-request links" do
    get edit_person_path(person)

    expect(response).to be_successful
    expect(response.body).to include("Sunrise Center")
    expect(response.body).to include("Jan 2018 – Jun 2020")
    expect(response.body).to include("Inactive")
    expect(response.body).to include("Request an affiliation change")
    expect(response.body).to include("field=affiliation")
    expect(response.body).to include("field=organization_name")
  end
end
