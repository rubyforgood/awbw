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

  it "links to the registrant importer from the Actions section, returning here" do
    get "/admin"

    expect(response.body).to include("Import registrants")
    expect(response.body).to include(%(href="#{new_event_registration_import_path(return_to: "admin_home")}"))
  end

  it "links to the form submissions index" do
    get "/admin"

    expect(response.body).to include("Form submissions")
    expect(response.body).to include(%(href="#{form_submissions_path}"))
  end

  it "opens the Activity card on the Activity tab" do
    get "/admin"

    expect(response.body).to include(%(href="#{admin_activities_events_path}"))
    expect(response.body).not_to include(%(href="#{admin_activities_counts_path}"))
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

  it "renders the action buttons right away and fills their badges from one frame request" do
    create(:profile_change_request)

    get "/admin"

    expect(response.body.scan(/<turbo-frame[^>]* src=/).size).to eq(1)
    expect(response.body).to include(%(src="#{admin_home_action_buttons_path}"))
    expect(response.body).to include(%(href="#{admin_data_health_path}"), %(href="#{author_credit_divergences_path}"))
    expect(response.body[%r{<turbo-frame id="action_buttons".*?</turbo-frame>}m]).not_to include("rounded-full")
  end

  describe "action buttons frame" do
    def get_action_buttons
      get admin_home_action_buttons_path, headers: { "Turbo-Frame" => "action_buttons" }
    end

    def button(label)
      response.body[%r{<(?:a|button)[^>]*>(?:(?!</(?:a|button)>).)*#{label}.*?</(?:a|button)>}m]
    end

    before do
      allow(DataHealth).to receive(:checks).and_return([ instance_double(DataHealth::Check, flagged?: false), instance_double(DataHealth::Check, flagged?: true) ])
      allow_any_instance_of(AuthorCreditDivergenceQuery).to receive(:any?).and_return(true)
      allow_any_instance_of(FeatureCatalog).to receive(:recent_missing?).and_return(true)
    end

    it "shows Review on Data health, Author credit, and Sync features, and the pending change request count" do
      create_list(:profile_change_request, 2)

      get_action_buttons

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="action_buttons"), %(target="_top"))
      expect(response.body).not_to include("<turbo-stream")
      expect(button("Changes requested")).to match(%r{<span[^>]*>2</span>})
      expect(button("Data health")).to match(%r{<span[^>]*>Review</span>}).and include("Data checks only")
      expect(button("Author credit divergences")).to match(%r{<span[^>]*>Review</span>})
      expect(button("Sync features")).to match(%r{<span[^>]*>Review</span>})
    end

    it "renders no badge when nothing is waiting" do
      allow(DataHealth).to receive(:checks).and_return([ instance_double(DataHealth::Check, flagged?: false) ])
      allow_any_instance_of(AuthorCreditDivergenceQuery).to receive(:any?).and_return(false)
      allow_any_instance_of(FeatureCatalog).to receive(:recent_missing?).and_return(false)

      get_action_buttons

      expect(response.body).to include("Data health", "Author credit divergences", "Sync features")
      expect(response.body).not_to include("rounded-full")
    end

    it "keeps the buttons and leaves only the failing badge empty when a check fails" do
      allow(DataHealth).to receive(:checks).and_raise(StandardError, "boom")

      get_action_buttons

      expect(response).to have_http_status(:ok)
      expect(button("Data health")).not_to include("rounded-full")
      expect(button("Author credit divergences")).to match(%r{<span[^>]*>Review</span>})
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get_action_buttons

      expect(response).not_to have_http_status(:ok)
    end
  end
end
