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
    create_tagging_event(organization, tagging)

    get edit_organization_path(organization)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Housing")
  end

  # The referenced records load in one batch per type, so a longer log costs no
  # more queries than a short one.
  it "does not query per reference as the change log grows" do
    organization = create(:organization)

    create_tagging_event(organization, create(:sectorable_item, sectorable: organization))
    one_event = tagging_queries_for(edit_organization_path(organization))

    2.times { create_tagging_event(organization, create(:sectorable_item, sectorable: organization)) }
    three_events = tagging_queries_for(edit_organization_path(organization))

    expect(response).to have_http_status(:ok)
    expect(three_events).to eq(one_event)
  end

  def create_tagging_event(organization, tagging)
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
  end

  def tagging_queries_for(path)
    count = 0
    counter = ->(_n, _s, _f, _i, payload) { count += 1 if payload[:sql]&.match?(/SELECT.+FROM `sectorable_items`/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end
end
