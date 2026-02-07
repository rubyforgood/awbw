# spec/requests/admin/analytics_spec.rb
require "rails_helper"

RSpec.describe "Admin::Analytics", type: :request do
  let(:admin_user)   { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:index_path) { admin_activities_counts_path } # GET /admin/activities/counts
  let(:print_path) { admin_analytics_print_path }

  # ============================================================
  # AS A GUEST
  # ============================================================

  context "as a guest" do
    describe "GET /admin/activities/counts" do
      it "redirects to root" do
        get index_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /admin/activities/counts/print" do
      it "records a print analytics event for a workshop" do
        workshop = create(:workshop, :published)

        expect_any_instance_of(Admin::AnalyticsController)
          .to receive(:track_print)
                .with(workshop)

        post print_path,
             params: {
               printable_type: "Workshop",
               printable_id: workshop.id
             },
             as: :json

        expect(response).to have_http_status(:ok)
      end

      it "returns bad request for invalid printable type" do
        post print_path,
             params: {
               printable_type: "InvalidType",
               printable_id: 99999
             },
             as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it "returns not found for non-existent resource" do
        post print_path,
             params: {
               printable_type: "Workshop",
               printable_id: 999999
             },
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ============================================================
  # AS A REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in regular_user }

    describe "GET /admin/activities/counts" do
      it "redirects to root (unauthorized)" do
        get index_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /admin/activities/counts/print" do
      it "records a print analytics event for a workshop" do
        workshop = create(:workshop, :published)

        expect_any_instance_of(Admin::AnalyticsController)
          .to receive(:track_print)
                .with(workshop)

        post print_path,
             params: {
               printable_type: "Workshop",
               printable_id: workshop.id
             },
             as: :json

        expect(response).to have_http_status(:ok)
      end

      it "returns bad request for invalid printable type" do
        post print_path,
             params: {
               printable_type: "InvalidType",
               printable_id: 99999
             },
             as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it "returns not found for non-existent resource" do
        post print_path,
             params: {
               printable_type: "Workshop",
               printable_id: 999999
             },
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ============================================================
  # AS AN ADMIN
  # ============================================================

  context "as an admin" do
    before { sign_in admin_user }

    describe "GET /admin/activities/counts" do
      it "renders successfully" do
        get index_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /admin/activities/counts/print" do
      it "records a print analytics event for a workshop" do
        workshop = create(:workshop, :published)

        expect_any_instance_of(Admin::AnalyticsController)
          .to receive(:track_print)
                .with(workshop)

        post print_path,
             params: {
               printable_type: "Workshop",
               printable_id: workshop.id
             },
             as: :json

        expect(response).to have_http_status(:ok)
      end

      it "returns bad request for invalid printable type" do
        post print_path,
             params: {
               printable_type: "InvalidType",
               printable_id: 99999
             },
             as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it "returns not found for non-existent resource" do
        post print_path,
             params: {
               printable_type: "Workshop",
               printable_id: 999999
             },
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
