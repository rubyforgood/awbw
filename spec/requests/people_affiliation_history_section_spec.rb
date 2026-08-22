require "rails_helper"

RSpec.describe "Person profile affiliation history section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:outsider) { create(:user) }
  let(:organization) { create(:organization, name: "Sunrise Center") }

  def get_history_section
    get person_path(person, section: "affiliation_history"),
        headers: { "Turbo-Frame" => "person_affiliation_history_section" }
  end

  before do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: Date.new(2018, 1, 1),
                         end_date: Date.new(2020, 6, 1), inactive: true)
  end

  it "shows the full history (incl. ended affiliations) to the owner" do
    sign_in owner_user
    get_history_section

    expect(response).to be_successful
    expect(response.body).to include("Sunrise Center")
    expect(response.body).to include("Inactive")
    expect(response.body).to include("Contact us to request a change")
  end

  it "shows the history to an admin" do
    sign_in admin
    get_history_section

    expect(response).to be_successful
    expect(response.body).to include("Sunrise Center")
  end

  # own_record? stays narrow (admin || owner) even after show? is widened for
  # public profile viewing, so a crafted ?section= request can't reach it.
  it "denies the history section to a non-owner" do
    sign_in outsider
    get_history_section

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include("Sunrise Center")
  end
end
