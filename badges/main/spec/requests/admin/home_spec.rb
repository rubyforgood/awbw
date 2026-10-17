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

  it "groups Banners, FAQs, Features & tips, and Smart resource settings under System settings & details" do
    get "/admin"

    expect(response.body).to include("System settings &amp; details", "Smart resource settings")
    expect(response.body).to include(
      %(href="#{banners_path}"),
      %(href="#{faqs_path}"),
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

  it "loads the action counts in lazy frames" do
    get "/admin"

    expect(response.body).to include(
      %(src="#{admin_home_data_health_count_path}"),
      %(src="#{admin_home_author_credit_count_path}"),
      %(src="#{admin_home_unsynced_features_count_path}")
    )
  end

  describe "count badges" do
    it "renders the Data health total inside its frame" do
      allow(DataHealth).to receive(:checks).and_return([ instance_double(DataHealth::Check, count: 2), instance_double(DataHealth::Check, count: 3) ])

      get admin_home_data_health_count_path, headers: { "Turbo-Frame" => "data_health_count" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="data_health_count"))
      expect(response.body).to match(%r{<span[^>]*>5</span>})
      expect(response.body).to include("Data checks only")
    end

    it "renders the Author credit total inside its frame" do
      entries = [ 1, 4 ].map { |count| DataHealth::Worklists::Entry.new("Label", count, "record", "/") }
      allow_any_instance_of(DataHealth::Worklists).to receive(:author_credit).and_return(entries)

      get admin_home_author_credit_count_path, headers: { "Turbo-Frame" => "author_credit_count" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="author_credit_count"))
      expect(response.body).to match(%r{<span[^>]*>5</span>})
    end

    it "renders how many seeded features aren't synced yet" do
      allow_any_instance_of(FeatureCatalog).to receive(:missing_count).and_return(3)

      get admin_home_unsynced_features_count_path, headers: { "Turbo-Frame" => "unsynced_features_count" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="unsynced_features_count"))
      expect(response.body).to match(%r{<span[^>]*>3</span>})
    end

    it "renders no badge when nothing is waiting" do
      allow(DataHealth).to receive(:checks).and_return([ instance_double(DataHealth::Check, count: 0) ])

      get admin_home_data_health_count_path, headers: { "Turbo-Frame" => "data_health_count" }

      expect(response.body).to include(%(id="data_health_count"))
      expect(response.body).not_to include("rounded-full")
    end

    it "renders an empty frame when a count fails" do
      allow(DataHealth).to receive(:checks).and_raise(StandardError, "boom")

      get admin_home_data_health_count_path, headers: { "Turbo-Frame" => "data_health_count" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="data_health_count"))
      expect(response.body).not_to include("rounded-full")
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get admin_home_data_health_count_path, headers: { "Turbo-Frame" => "data_health_count" }

      expect(response).not_to have_http_status(:ok)
    end
  end
end
