require "rails_helper"

# The org "Associated records" card links each contributed-content index filtered
# to the org via organization_id. These cover the filters the card added.
RSpec.describe "Contributed-content indexes filtered by organization", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization, name: "Filter Org") }
  let(:member) { create(:person) }

  before do
    create(:affiliation, organization: organization, person: member)
    sign_in admin
  end

  it "scopes resources to the org and names it in the banner" do
    create(:resource, title: "Org Resource", organization: organization)
    create(:resource, title: "Other Resource")

    get resources_path(organization_id: organization.id)
    expect(response.body).to include("Filtered to", "Filter Org")

    get resources_path(organization_id: organization.id), headers: { "Turbo-Frame" => "resources_results" }
    expect(response.body).to include("Org Resource")
    expect(response.body).not_to include("Other Resource")
  end

  it "scopes workshops to those credited to the org's people" do
    create(:workshop, published: true, title: "Org Workshop", author: member)
    create(:workshop, published: true, title: "Other Workshop", author: create(:person))

    get workshops_path(organization_id: organization.id)
    expect(response.body).to include("Filtered to", "Filter Org")

    get workshops_path(organization_id: organization.id), headers: { "Turbo-Frame" => "workshops_results" }
    expect(response.body).to include("Org Workshop")
    expect(response.body).not_to include("Other Workshop")
  end

  it "scopes workshop variations to the org" do
    published_workshop = create(:workshop, published: true)
    create(:workshop_variation, name: "Org Variation", workshop: published_workshop, organization: organization)
    create(:workshop_variation, name: "Other Variation", workshop: published_workshop)

    get workshop_variations_path(organization_id: organization.id)
    expect(response.body).to include("Filtered to", "Filter Org")

    get workshop_variations_path(organization_id: organization.id), headers: { "Turbo-Frame" => "workshop_variations_results" }
    expect(response.body).to include("Org Variation")
    expect(response.body).not_to include("Other Variation")
  end

  it "scopes workshop ideas to those the org's people submitted" do
    create(:workshop_idea, title: "Org Idea", created_by: create(:user, person: member))
    create(:workshop_idea, title: "Other Idea")

    get workshop_ideas_path(organization_id: organization.id)
    expect(response.body).to include("Org Idea")
    expect(response.body).not_to include("Other Idea")
  end

  it "scopes workshop variation ideas to the org" do
    create(:workshop_variation_idea, name: "Org Variation Idea", organization: organization)
    create(:workshop_variation_idea, name: "Other Variation Idea")

    get workshop_variation_ideas_path(organization_id: organization.id)
    expect(response.body).to include("Org Variation Idea")
    expect(response.body).not_to include("Other Variation Idea")
  end
end
