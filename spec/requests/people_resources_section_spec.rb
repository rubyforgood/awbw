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

  it "excludes resources the person's user merely created (audit trail only)" do
    create(:resource, :published, title: "Only Created Resource", created_by: owner_user)

    get_resources_section

    expect(response.body).not_to include("Only Created Resource")
  end
end
