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
    end
  end
end
