require "rails_helper"

RSpec.describe "Person profile stories section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_stories_section
    get person_path(person, section: "stories"),
        headers: { "Turbo-Frame" => "person_stories_section" }
  end

  it "shows stories the person authored" do
    create(:story, :published, title: "Authored Story", author: person)

    get_stories_section

    expect(response).to be_successful
    expect(response.body).to include("Authored Story")
  end

  it "shows stories the person was spotlighted in" do
    create(:story, :published, title: "Spotlight Story", spotlighted_facilitator: person)

    get_stories_section

    expect(response.body).to include("Spotlight Story")
  end

  it "excludes stories the person's user merely created (audit trail only)" do
    create(:story, :published, title: "Only Created Story", created_by: owner_user)

    get_stories_section

    expect(response.body).not_to include("Only Created Story")
  end
end
