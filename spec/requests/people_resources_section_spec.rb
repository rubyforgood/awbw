require "rails_helper"

RSpec.describe "Person profile resources section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_resources_section
    get person_path(person, section: "resources"),
        headers: { "Turbo-Frame" => "person_resources_section" }
  end

  it "shows resources the person authored" do
    create(:resource, :published, title: "Authored Resource", author: person)

    get_resources_section

    expect(response).to be_successful
    expect(response.body).to include("Authored Resource")
  end

  it "includes unauthored resources the person's user created (legacy fallback)" do
    create(:resource, :published, title: "Only Created Resource", created_by: owner_user, author: nil)

    get_resources_section

    expect(response.body).to include("Only Created Resource")
  end

  it "excludes resources the person's user created but credited to someone else" do
    create(:resource, :published, title: "Someone Elses Resource",
                                  created_by: owner_user, author: create(:person))

    get_resources_section

    expect(response.body).not_to include("Someone Elses Resource")
  end
end
