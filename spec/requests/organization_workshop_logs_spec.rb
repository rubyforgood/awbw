require "rails_helper"

# The org profile's workshop-log cards link here — the org's own grouped page, the
# twin of the person profile's.
RSpec.describe "Organization workshop logs page", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:viewer) { create(:user) }
  let(:organization) { create(:organization) }
  let(:facilitator) { create(:person) }
  let(:member) { create(:user, person: facilitator) }
  let(:collage) { create(:workshop, title: "Collage Workshop") }

  before { create(:affiliation, organization: organization, person: facilitator) }

  it "groups every logged workshop, each card linking to its own group" do
    create(:workshop_log, organization: organization, workshop: collage)
    create(:workshop_log, organization: organization, workshop: nil, external_workshop_title: "Outside Workshop")
    sign_in member

    get workshop_logs_organization_path(organization)

    body = Capybara.string(response.body)
    expect(body).to have_text("Workshop logs for #{organization.name}")
    expect(body).to have_link(href: workshop_logs_organization_path(organization, workshop_id: collage.id))
    expect(body).to have_link(href: workshop_logs_organization_path(organization, external_title: "Outside Workshop"))
    expect(body).to have_link(href: organization_path(organization, anchor: "workshop_logs"))
  end

  it "lists one group's date rows when a workshop is named" do
    create(:workshop_log, organization: organization, workshop: collage, adults_first_time: 4)
    create(:workshop_log, organization: organization, workshop: create(:workshop, title: "Masks Workshop"))
    sign_in member

    get workshop_logs_organization_path(organization, workshop_id: collage.id)

    expect(response.body).to include("Collage Workshop")
    expect(response.body).not_to include("Masks Workshop")
  end

  it "lists one group's date rows when an outside title is named" do
    create(:workshop_log, organization: organization, workshop: nil, external_workshop_title: "Outside Workshop")
    create(:workshop_log, organization: organization, workshop: collage)
    sign_in member

    get workshop_logs_organization_path(organization, external_title: "Outside Workshop")

    expect(response.body).to include("Outside Workshop")
    expect(response.body).not_to include("Collage Workshop")
  end

  it "turns away non-members" do
    create(:workshop_log, organization: organization, workshop: collage)
    sign_in viewer

    get workshop_logs_organization_path(organization)

    expect(response.body).not_to include("Collage Workshop")
  end

  it "turns away members, but not admins, when the org hides its logs" do
    organization.update!(profile_show_workshop_logs: false)
    create(:workshop_log, organization: organization, workshop: collage)

    sign_in member
    get workshop_logs_organization_path(organization)
    expect(response.body).not_to include("Collage Workshop")

    sign_in admin
    get workshop_logs_organization_path(organization)
    expect(response.body).to include("Collage Workshop")
  end
end
