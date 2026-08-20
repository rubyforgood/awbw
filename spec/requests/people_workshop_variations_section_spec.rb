require "rails_helper"

RSpec.describe "Person profile workshop variations section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_workshop_variations_section
    get person_path(person, section: "workshop_variations"),
        headers: { "Turbo-Frame" => "person_workshop_variations_section" }
  end

  it "shows variations the person authored" do
    create(:workshop_variation, name: "Authored Variation", author: person)

    get_workshop_variations_section

    expect(response).to be_successful
    expect(response.body).to include("Authored Variation")
  end

  it "excludes variations the person's user merely created (audit trail only)" do
    create(:workshop_variation, name: "Only Created Variation", created_by: owner_user)

    get_workshop_variations_section

    expect(response.body).not_to include("Only Created Variation")
  end
end
