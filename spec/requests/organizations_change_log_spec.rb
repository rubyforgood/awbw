require "rails_helper"

RSpec.describe "Organizations change log", type: :request do
  before { sign_in create(:user, :admin) }

  it_behaves_like "a page with a change log" do
    let(:record) { create(:organization) }
    let(:page_path) { edit_organization_path(record) }
  end

  # Sector taggings are nested attributes on the org, so its change log
  # references them — and reaching for their label used to raise.
  it "renders a change log that references the org's sector taggings" do
    organization = create(:organization)
    tagging = create(:sectorable_item, sectorable: organization, sector: create(:sector, name: "Housing"))
    create(
      :ahoy_event,
      name: "update.organization",
      resource_type: "Organization",
      resource_id: organization.id,
      properties: {
        resource_type: "Organization", resource_id: organization.id,
        association_changes: { sectorable_items: [ { action: "added", type: "SectorableItem", id: tagging.id } ] }
      }
    )

    get edit_organization_path(organization)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Housing")
  end
end
