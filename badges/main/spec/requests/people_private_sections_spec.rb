require "rails_helper"

RSpec.describe "Person profile private (submitted) sections", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:outsider) { create(:user) }

  # The "Submitted content" sections load lazily via a Turbo Frame, so request
  # story_ideas the way the frame does.
  def get_story_ideas_section
    get person_path(person, section: "story_ideas"),
        headers: { "Turbo-Frame" => "person_story_ideas_section" }
  end

  before do
    # The section lists ideas by authorship; the story-idea card titles by
    # workshop_title, so put the marker there.
    create(:story_idea, created_by: owner_user, updated_by: owner_user, author: person,
                        external_workshop_title: "My Private Submission")
  end

  it "shows the submitted section to an admin" do
    sign_in admin
    get_story_ideas_section

    expect(response).to be_successful
    expect(response.body).to include("My Private Submission")
  end

  it "shows the submitted section to the owner" do
    sign_in owner_user
    get_story_ideas_section

    expect(response).to be_successful
    expect(response.body).to include("My Private Submission")
  end

  # own_record? stays narrow (admin || owner) even after show? is widened for
  # public profile viewing, so a crafted ?section= request can't reach it.
  it "denies the submitted section to a non-owner" do
    sign_in outsider
    get_story_ideas_section

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include("My Private Submission")
  end
end
