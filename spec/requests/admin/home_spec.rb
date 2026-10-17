require "rails_helper"

RSpec.describe "Admin home", type: :request do
  before { sign_in create(:user, :admin) }

  it "renders with the Features & tips card and the Actions sync button" do
    get "/admin"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Features &amp; tips")
    expect(response.body).to include("Actions")
    expect(response.body).to include("Sync features")
  end

  it "puts Data health and Author credit divergences in the Actions section" do
    get "/admin"

    expect(response.body).to include("Data health", "Author credit divergences")
    expect(response.body).to include(
      %(href="#{admin_data_health_path}"),
      %(href="#{author_credit_divergences_path}")
    )
  end

  it "links to the form submissions index" do
    get "/admin"

    expect(response.body).to include("Form submissions")
    expect(response.body).to include(%(href="#{form_submissions_path}"))
  end

  it "links to the cross-event timesheets" do
    get "/admin"

    expect(response.body).to include("Timesheets")
    expect(response.body).to include(%(href="#{signins_events_path}"))
  end

  it "links to the record dedupers under the Dedupers section" do
    get "/admin"

    expect(response.body).to include("Dedupers")
    expect(response.body).to include("Dedupe organizations", "Dedupe categories", "Dedupe sectors")
    expect(response.body).to include(
      %(href="#{dedupe_index_organizations_path}"),
      %(href="#{dedupe_index_categories_path}"),
      %(href="#{dedupe_index_sectors_path}")
    )
  end

  it "groups Features & tips and Smart resource settings under System settings & details" do
    get "/admin"

    expect(response.body).to include("System settings &amp; details", "Smart resource settings")
    expect(response.body).to include(
      %(href="#{features_path}"),
      %(href="#{admin_resource_roles_path}")
    )
  end

  it "lists Organization statuses under the Deprecated data section" do
    get "/admin"

    expect(response.body).to include("Deprecated data")
    expect(response.body).to include("Organization statuses")
    expect(response.body).to include(%(href="#{organization_statuses_path}"))
  end
end
