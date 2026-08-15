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
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "GET /admin/activities/visits" do
      it "redirects and does not expose visits" do
        get visits_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "GET /admin/activities/charts" do
      it "redirects and does not expose charts" do
        get charts_path
        expect(response).to redirect_to(new_user_session_path)
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

      it "filters by person_id to the person, their user, and associated data" do
        person = create(:person)
        payment = create(:payment, person: person)
        unrelated_person = create(:person)

        create(:ahoy_event, name: "update.person", visit: visit_for_admin,
                            resource_type: "Person", resource_id: person.id, time: 1.day.ago,
                            properties: { "resource_type" => "Person", "resource_id" => person.id, "resource_title" => "person_history_row" })
        create(:ahoy_event, name: "update.user", visit: visit_for_admin,
                            resource_type: "User", resource_id: person.user.id, time: 1.day.ago,
                            properties: { "resource_type" => "User", "resource_id" => person.user.id, "resource_title" => "user_history_row" })
        create(:ahoy_event, name: "create.payment", visit: visit_for_admin,
                            resource_type: "Payment", resource_id: payment.id, time: 1.day.ago,
                            properties: { "resource_type" => "Payment", "resource_id" => payment.id, "resource_title" => "payment_history_row" })
        create(:ahoy_event, name: "update.person", visit: visit_for_admin,
                            resource_type: "Person", resource_id: unrelated_person.id, time: 1.day.ago,
                            properties: { "resource_type" => "Person", "resource_id" => unrelated_person.id, "resource_title" => "unrelated_history_row" })

        get index_path, params: { person_id: person.id, time_period: "all_time", audience: %w[visitors users staff] }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("person_history_row")
        expect(response.body).to include("user_history_row")
        expect(response.body).to include("payment_history_row")
        expect(response.body).not_to include("unrelated_history_row")
      end

      it "surfaces a person chip in the applied filters when person_id is set" do
        person = create(:person, first_name: "Ada", last_name: "Lovelace")

        get index_path, params: { person_id: person.id, time_period: "all_time", audience: %w[visitors users staff] }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Person: #{person.name}")
      end

      it "shows a back-to-person eyebrow (not Admin) when scoped to a person" do
        person = create(:person, first_name: "Ada", last_name: "Lovelace")

        get index_path, params: { person_id: person.id, time_period: "all_time", audience: %w[visitors users staff] }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(edit_person_path(person))
      end

      it "surfaces the person's communications (notifications) on the activities page" do
        person = create(:person)
        create(:notification, recipient_email: person.communications_email, email_subject: "Comms row marker xyz")

        get index_path, params: { person_id: person.id, time_period: "all_time", audience: %w[visitors users staff] }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Communications")
        expect(response.body).to include("Comms row marker xyz")
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
          "Workshop search: category types",
          "Workshop search: categories",
          "Workshop search: sectors",
          "Workshop search: titles",
          "Workshop search: authors",
          "Workshop search: full-text",
          "Workshop search: windows audiences",
          "Workshop search: no results",
          "Workshop discovery funnel",
          "Content types people view most",
          "Content types printed most",
          "How users discover content",
          "Search-to-view conversion"
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
          name: "search.taggings",
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

    # ==============================================================
    # Audience filtering
    # ==============================================================

    describe "charts audience filtering" do
      let(:regular_user) { create(:user, super_user: false, first_name: "Regular", last_name: "Person") }
      let(:staff_user)   { create(:user, super_user: true, first_name: "Staff", last_name: "Admin") }

      let(:visitor_visit) { create(:ahoy_visit, user: nil, started_at: 2.days.ago) }
      let(:user_visit)    { create(:ahoy_visit, user: regular_user, started_at: 2.days.ago) }
      let(:staff_visit)   { create(:ahoy_visit, user: staff_user, started_at: 2.days.ago) }

      let!(:visitor_event) do
        create(:ahoy_event, name: "view.workshop", user: nil, visit: visitor_visit,
               time: 2.days.ago, properties: { "resource_type" => "Workshop" })
      end

      let!(:user_event) do
        create(:ahoy_event, name: "view.workshop", user: regular_user, visit: user_visit,
               time: 2.days.ago, properties: { "resource_type" => "Workshop" })
      end

      let!(:staff_event) do
        create(:ahoy_event, name: "view.workshop", user: staff_user, visit: staff_visit,
               time: 2.days.ago, properties: { "resource_type" => "Workshop" })
      end

      it "visitors-only renders successfully" do
        get charts_path, params: { time_period: "all_time", audience: [ "visitors" ] }

        expect(response).to have_http_status(:ok)
        # Should not show the authenticated/public split hint since all visits are public
        expect(response.body).not_to include("authenticated · ")
      end

      it "users-only excludes visitor data from response" do
        get charts_path, params: { time_period: "all_time", audience: [ "users" ] }

        expect(response).to have_http_status(:ok)
        body = response.body
        # Non-admin only label should be shown
        expect(body).to include("Non-admin only")
      end

      it "staff-only shows admin-only label" do
        get charts_path, params: { time_period: "all_time", audience: [ "staff" ] }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin only")
      end

      it "all audiences renders without audience restriction labels" do
        get charts_path, params: { time_period: "all_time", audience: %w[visitors users staff] }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Non-admin only")
        expect(response.body).not_to include("Admin only")
      end

      it "filters workshop search data by audience" do
        create(:ahoy_event, name: "search.workshops", user: regular_user, visit: user_visit,
               time: 2.days.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 1,
                 "keywords" => { "title" => "unique_user_search_xyz" },
                 "filters" => { "categories" => [], "sectors" => [], "windows_types" => [] }
               })

        get charts_path, params: { time_period: "all_time", audience: [ "visitors" ] }
        expect(response.body).not_to include("unique_user_search_xyz")

        get charts_path, params: { time_period: "all_time", audience: [ "users" ] }
        expect(response.body).to include("unique_user_search_xyz")
      end

      it "filters tagging data by audience" do
        create(:ahoy_event, name: "search.taggings", user: regular_user, visit: user_visit,
               time: 2.days.ago, properties: {
                 "sectors" => [ "AudienceTestSector" ], "categories" => [], "page_result_count" => 5
               })

        get charts_path, params: { time_period: "all_time", audience: [ "visitors" ] }
        expect(response.body).not_to include("AudienceTestSector")

        get charts_path, params: { time_period: "all_time", audience: [ "users" ] }
        expect(response.body).to include("AudienceTestSector")
      end

      it "visitors-only shows no top engaged users" do
        get charts_path, params: { time_period: "all_time", audience: [ "visitors" ] }

        # Top users by activities chart should have no user names since visitors are anonymous
        expect(response.body).not_to include(regular_user.full_name)
        expect(response.body).not_to include(staff_user.full_name)
      end

      it "users-only portal metrics exclude staff" do
        get charts_path, params: { time_period: "all_time", audience: [ "users" ] }

        body = response.body
        expect(body).to include("Non-admin only")
        # User count should match non-admin count
        non_admin_count = User.where(super_user: false).count
        expect(body).to include(non_admin_count.to_s)
      end
    end

    # ==============================================================
    # Time period filtering
    # ==============================================================

    describe "charts time period filtering" do
      let(:recent_visit) { create(:ahoy_visit, user: user, started_at: 2.days.ago) }
      let(:old_visit)    { create(:ahoy_visit, user: user, started_at: 2.months.ago) }

      let!(:recent_event) do
        create(:ahoy_event, name: "view.workshop", user: user, visit: recent_visit,
               time: 2.days.ago, properties: { "resource_type" => "Workshop", "resource_title" => "RecentWorkshop" })
      end

      let!(:old_event) do
        create(:ahoy_event, name: "view.workshop", user: user, visit: old_visit,
               time: 2.months.ago, properties: { "resource_type" => "Workshop", "resource_title" => "OldWorkshop" })
      end

      it "past_week renders successfully" do
        get charts_path, params: { time_period: "past_week", audience: %w[visitors users staff] }
        expect(response).to have_http_status(:ok)
      end

      it "all_time renders successfully" do
        get charts_path, params: { time_period: "all_time", audience: %w[visitors users staff] }
        expect(response).to have_http_status(:ok)
      end

      it "time filter applies to workshop search charts" do
        create(:ahoy_event, name: "search.workshops", user: user, visit: recent_visit,
               time: 2.days.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 1,
                 "keywords" => { "title" => "recent_search_term_abc" },
                 "filters" => { "categories" => [], "sectors" => [], "windows_types" => [] }
               })
        create(:ahoy_event, name: "search.workshops", user: user, visit: old_visit,
               time: 2.months.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 1,
                 "keywords" => { "title" => "old_search_term_xyz" },
                 "filters" => { "categories" => [], "sectors" => [], "windows_types" => [] }
               })

        get charts_path, params: { time_period: "past_week", audience: %w[visitors users staff] }
        expect(response.body).to include("recent_search_term_abc")
        expect(response.body).not_to include("old_search_term_xyz")
      end

      it "time filter applies to tagging charts" do
        create(:ahoy_event, name: "search.taggings", user: user, visit: recent_visit,
               time: 2.days.ago, properties: {
                 "sectors" => [ "RecentSectorXyz" ], "categories" => [], "page_result_count" => 5
               })
        create(:ahoy_event, name: "search.taggings", user: user, visit: old_visit,
               time: 2.months.ago, properties: {
                 "sectors" => [ "OldSectorXyz" ], "categories" => [], "page_result_count" => 3
               })

        get charts_path, params: { time_period: "past_week", audience: %w[visitors users staff] }
        expect(response.body).to include("RecentSectorXyz")
        expect(response.body).not_to include("OldSectorXyz")
      end

      it "time filter applies to zero-result searches" do
        create(:ahoy_event, name: "search_zero.workshops", user: user, visit: recent_visit,
               time: 2.days.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 0,
                 "query" => "recent_zero_query"
               })
        create(:ahoy_event, name: "search_zero.workshops", user: user, visit: old_visit,
               time: 2.months.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 0,
                 "query" => "old_zero_query"
               })

        get charts_path, params: { time_period: "past_week", audience: %w[visitors users staff] }
        expect(response.body).to include("recent_zero_query")
        expect(response.body).not_to include("old_zero_query")
      end
    end

    # ==============================================================
    # Combined audience + time filtering
    # ==============================================================

    describe "charts combined audience and time filtering" do
      let(:regular_user) { create(:user, super_user: false) }
      let(:recent_user_visit)    { create(:ahoy_visit, user: regular_user, started_at: 2.days.ago) }
      let(:recent_visitor_visit) { create(:ahoy_visit, user: nil, started_at: 2.days.ago) }
      let(:old_user_visit)       { create(:ahoy_visit, user: regular_user, started_at: 2.months.ago) }

      let!(:recent_user_search) do
        create(:ahoy_event, name: "search.workshops", user: regular_user, visit: recent_user_visit,
               time: 2.days.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 1,
                 "keywords" => { "title" => "combined_user_recent" },
                 "filters" => { "categories" => [], "sectors" => [], "windows_types" => [] }
               })
      end

      let!(:recent_visitor_search) do
        create(:ahoy_event, name: "search.workshops", user: nil, visit: recent_visitor_visit,
               time: 2.days.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 1,
                 "keywords" => { "title" => "combined_visitor_recent" },
                 "filters" => { "categories" => [], "sectors" => [], "windows_types" => [] }
               })
      end

      let!(:old_user_search) do
        create(:ahoy_event, name: "search.workshops", user: regular_user, visit: old_user_visit,
               time: 2.months.ago, properties: {
                 "resource_type" => "Workshop", "result_count" => 1,
                 "keywords" => { "title" => "combined_user_old" },
                 "filters" => { "categories" => [], "sectors" => [], "windows_types" => [] }
               })
      end

      it "users + past_week includes only recent user data" do
        get charts_path, params: { time_period: "past_week", audience: [ "users" ] }

        body = response.body
        expect(body).to include("combined_user_recent")
        expect(body).not_to include("combined_visitor_recent")
        expect(body).not_to include("combined_user_old")
      end

      it "visitors + past_week includes only recent visitor data" do
        get charts_path, params: { time_period: "past_week", audience: [ "visitors" ] }

        body = response.body
        expect(body).to include("combined_visitor_recent")
        expect(body).not_to include("combined_user_recent")
        expect(body).not_to include("combined_user_old")
      end

      it "all audiences + all_time includes everything" do
        get charts_path, params: { time_period: "all_time", audience: %w[visitors users staff] }

        body = response.body
        expect(body).to include("combined_user_recent")
        expect(body).to include("combined_visitor_recent")
        expect(body).to include("combined_user_old")
      end
    end
  end
end
