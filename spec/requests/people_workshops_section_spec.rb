require "rails_helper"

RSpec.describe "Person profile workshops section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_workshops_section
    get person_path(person, section: "workshops"),
        headers: { "Turbo-Frame" => "person_workshops_section" }
  end

  it "shows workshops the person authored" do
    create(:workshop, :published, title: "Authored Workshop", author: person)

    get_workshops_section

    expect(response).to be_successful
    expect(response.body).to include("Authored Workshop")
  end

  it "excludes workshops the person's user merely created (audit trail only)" do
    create(:workshop, :published, title: "Only Created Workshop", created_by: owner_user)

    get_workshops_section

    expect(response.body).not_to include("Only Created Workshop")
  end
end
