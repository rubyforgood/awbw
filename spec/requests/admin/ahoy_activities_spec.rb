# spec/requests/admin/ahoy_activities_spec.rb
require "rails_helper"

RSpec.describe "Admin::AhoyActivities", type: :request do
  let(:admin) { create(:user, super_user: true) }
  let(:user)  { create(:user, super_user: false) }

  # Minimal Ahoy data for filter assertions (only used in admin context)
  let!(:visit_for_user)  { create(:ahoy_visit, user: user, started_at: 2.days.ago) }
  let!(:visit_for_admin) { create(:ahoy_visit, user: admin, started_at: 1.day.ago) }

  let!(:auth_event) do
    create(
      :ahoy_event,
      name: "auth.login",
      user: nil,
      visit: create(:ahoy_visit, user: nil, started_at: 1.day.ago),
      time: 1.day.ago,
      properties: { "sign_in_count" => 1 }
    )
  end

  let!(:create_event) do
    create(
      :ahoy_event,
      name: "create.bookmark",
      user: user,
      visit: visit_for_user,
      resource_type: "Bookmark",
      resource_id: 123,
      time: 2.days.ago,
      properties: { "resource_id" => 123, "resource_type" => "Bookmark" }
    )
  end

  let(:index_path)  { admin_activities_events_path }          # GET /admin/activities
  let(:visits_path) { admin_activities_visits_path }   # GET /admin/activities/visits
  let(:charts_path) { admin_activities_charts_path }   # GET /admin/activities/charts

  # ============================================================
  # AS A GUEST
  # ============================================================

  context "as a guest" do
    describe "GET /admin/activities" do
      it "redirects and does not expose activity" do
        get index_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /admin/activities/visits" do
      it "redirects and does not expose visits" do
        get visits_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /admin/activities/charts" do
      it "redirects and does not expose charts" do
        get charts_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ============================================================
  # AS A REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in user }

    describe "GET /admin/activities" do
      it "redirects to root (unauthorized)" do
        get index_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    describe "GET /admin/activities/visits" do
      it "redirects to root (unauthorized)" do
        get visits_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    describe "GET /admin/activities/charts" do
      it "redirects to root (unauthorized)" do
        get charts_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  # ============================================================
  # AS AN ADMIN
  # ============================================================

  context "as an admin" do
    before { sign_in admin }

    describe "default filters" do
      it "shows Past month chip and Audience chips on events page" do
        get index_path
        expect(response.body).to include("Past month")
        expect(response.body).to include("Visitors")
        expect(response.body).to include("Users")
      end

      it "shows Past month chip and Audience chips on visits page" do
        get visits_path
        expect(response.body).to include("Past month")
        expect(response.body).to include("Visitors")
        expect(response.body).to include("Users")
      end

      it "shows Past month chip and Audience chips on charts page" do
        get charts_path
        expect(response.body).to include("Past month")
        expect(response.body).to include("Visitors")
        expect(response.body).to include("Users")
      end
    end

    describe "GET /admin/activities" do
      it "renders ok" do
        get index_path
        expect(response).to have_http_status(:ok)
      end

      it "filters by prefixes=auth" do
        get index_path, params: { prefixes: "auth" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("auth.login")
        expect(response.body).not_to include("create.bookmark")
      end

      it "filters by visit_id" do
        get index_path, params: { visit_id: visit_for_user.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("create.bookmark")
      end

      it "filters by from/to dates" do
        get index_path,
            params: {
              from: 3.days.ago.to_date.to_s,
              to: 1.day.ago.to_date.to_s
            }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("create.bookmark")
        expect(response.body).to include("auth.login")
      end

      it "filters by event name" do
        get index_path, params: { event_name: "auth.login", time_period: "all_time" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("auth.login")
        expect(response.body).not_to include("create.bookmark")
      end

      it "filters by partial event name" do
        get index_path, params: { event_name: "bookmark", time_period: "all_time" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("create.bookmark")
        expect(response.body).not_to include("auth.login")
      end
    end

    describe "GET /admin/activities/visits" do
      it "renders ok" do
        get visits_path
        expect(response).to have_http_status(:ok)
      end

      it "filters visits by user_id" do
        get visits_path, params: { user_id: user.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(user.full_name)
      end

      it "filters visits by visit_id" do
        get visits_path, params: { visit_id: visit_for_user.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(visit_for_user.id.to_s)
      end

      it "filters visits by from/to dates" do
        get visits_path,
            params: {
              from: 3.days.ago.to_date.to_s,
              to: 1.day.ago.to_date.to_s
            }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(visit_for_user.id.to_s)
      end
    end

    describe "GET /admin/activities/charts" do
      it "renders ok" do
        get charts_path
        expect(response).to have_http_status(:ok)
      end

      it "always renders chart titles even with no data" do
        get charts_path, params: { time_period: "all_time" }
        body = response.body

        [
          "Workshop Search: Category Types",
          "Workshop Search: Categories",
          "Workshop Search: Sectors",
          "Workshop Search: Titles",
          "Workshop Search: Authors",
          "Workshop Search: Full-Text",
          "Workshop search: Windows audiences",
          "Workshop Search: No Results",
          "Workshop Discovery Funnel",
          "Content Types People View Most",
          "Content Types Printed Most",
          "How Users Discover Content",
          "Search-to-View Conversion",
          "User Signup Trend"
        ].each do |title|
          expect(body).to include(title), "Expected chart title '#{title}' to be present"
        end
      end
    end

    # ==============================================================
    # Charts with populated data
    # ==============================================================

    describe "GET /admin/activities/charts with event data" do
      let(:visit) { create(:ahoy_visit, user: user, started_at: 2.days.ago) }

      let(:category_type) { create(:category_type, :published, name: "ArtType") }
      let(:category)      { create(:category, :published, name: "Drawing", category_type: category_type) }
      let(:sector)        { create(:sector, :published, name: "Domestic Violence") }
      let(:windows_type)  { create(:windows_type, :adult) }

      let!(:filter_event) do
        create(
          :ahoy_event,
          name: "filter.workshops",
          user: user,
          visit: visit,
          time: 2.days.ago,
          properties: {
            "resource_type" => "Workshop",
            "result_count" => 5,
            "filters" => {
              "categories" => [ { "id" => category.id, "name" => category.name, "type" => category_type.name } ],
              "sectors" => [ { "id" => sector.id, "name" => sector.name } ],
              "windows_types" => [ { "id" => windows_type.id, "name" => windows_type.name } ]
            }
          }
        )
      end

      let!(:search_event) do
        create(
          :ahoy_event,
          name: "search.workshops",
          user: user,
          visit: visit,
          time: 2.days.ago,
          properties: {
            "resource_type" => "Workshop",
            "result_count" => 3,
            "keywords" => { "title" => "self care", "author" => "fabian", "full_text" => "anxiety" },
            "filters" => {
              "categories" => [ { "id" => category.id, "name" => category.name, "type" => category_type.name } ],
              "sectors" => [ { "id" => sector.id, "name" => sector.name } ],
              "windows_types" => [ { "id" => windows_type.id, "name" => windows_type.name } ]
            }
          }
        )
      end

      let!(:zero_result_event) do
        create(
          :ahoy_event,
          name: "search_zero.workshops",
          user: user,
          visit: visit,
          time: 2.days.ago,
          properties: {
            "resource_type" => "Workshop",
            "result_count" => 0,
            "query" => "music therapy",
            "keywords" => { "full_text" => "music therapy" }
          }
        )
      end

      let!(:view_workshop_event) do
        create(
          :ahoy_event,
          name: "view.workshop",
          user: user,
          visit: visit,
          resource_type: "Workshop",
          resource_id: 1,
          time: 2.days.ago,
          properties: { "resource_type" => "Workshop", "resource_id" => 1 }
        )
      end

      let!(:view_resource_event) do
        create(
          :ahoy_event,
          name: "view.resource",
          user: user,
          visit: visit,
          resource_type: "Resource",
          resource_id: 1,
          time: 2.days.ago,
          properties: { "resource_type" => "Resource", "resource_id" => 1 }
        )
      end

      let!(:print_event) do
        create(
          :ahoy_event,
          name: "print.workshop",
          user: user,
          visit: visit,
          resource_type: "Workshop",
          resource_id: 1,
          time: 2.days.ago,
          properties: { "resource_type" => "Workshop", "resource_id" => 1 }
        )
      end

      let!(:tagging_event) do
        create(
          :ahoy_event,
          name: "browse.taggings",
          user: user,
          visit: visit,
          time: 2.days.ago,
          properties: {
            "sectors" => [ sector.name ],
            "categories" => [ category.name ],
            "page_result_count" => 10
          }
        )
      end

      it "renders charts page successfully" do
        get charts_path, params: { time_period: "all_time" }
        expect(response).to have_http_status(:ok)
      end

      it "populates workshop filter charts with category, sector, and windows type data" do
        get charts_path, params: { time_period: "all_time" }
        body = response.body

        expect(body).to include(category_type.name)
        expect(body).to include(category.name)
        expect(body).to include(sector.name)
        expect(body).to include(windows_type.short_name)
      end

      it "populates workshop keyword search charts" do
        get charts_path, params: { time_period: "all_time" }
        body = response.body

        expect(body).to include("self care")
        expect(body).to include("fabian")
        expect(body).to include("anxiety")
      end

      it "populates zero-result search chart" do
        get charts_path, params: { time_period: "all_time" }
        expect(response.body).to include("music therapy")
      end

      it "populates content type view pie chart with multiple types" do
        get charts_path, params: { time_period: "all_time" }
        body = response.body

        expect(body).to include("workshop")
        expect(body).to include("resource")
      end

      it "populates tagging charts with sector and category names" do
        get charts_path, params: { time_period: "all_time" }
        body = response.body

        expect(body).to include(sector.name)
        expect(body).to include(category.name)
      end
    end
  end
end
