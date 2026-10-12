require "rails_helper"

RSpec.describe "/features", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:user_facing) { create(:feature, name: "Facilitator feature", display_status: "user_facing", published: true) }
  let!(:admin_facing) { create(:feature, name: "Admin-only feature", display_status: "admin_facing", published: true) }
  let!(:draft) { create(:feature, name: "Draft feature", display_status: "user_facing", published: false) }

  # The list loads lazily in a Turbo frame; the full page renders the shell + form,
  # and the frame request renders the filtered cards.
  def frame_headers
    { "Turbo-Frame" => "features_results" }
  end

  describe "GET /features (page shell)" do
    it "redirects a logged-out visitor to sign in" do
      get features_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "renders the page with the search form" do
        get features_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Features &amp; tips")
        expect(response.body).to include('name="query"')
      end

      it "does not show admin actions" do
        get features_path
        expect(response.body).not_to include("Sync latest updates")
        expect(response.body).not_to include("New feature")
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows the New feature action (sync lives on the admin home)" do
        get features_path
        expect(response.body).to include("New feature")
        expect(response.body).not_to include("Sync latest updates")
      end
    end
  end

  describe "GET /features (results frame)" do
    context "as a regular user" do
      before { sign_in regular_user }

      it "lists published, non-admin-facing features only" do
        get features_path, headers: frame_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Facilitator feature")
        expect(response.body).not_to include("Admin-only feature")
        expect(response.body).not_to include("Draft feature")
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "lists every feature" do
        get features_path, headers: frame_headers
        expect(response.body).to include("Facilitator feature")
        expect(response.body).to include("Admin-only feature")
        expect(response.body).to include("Draft feature")
      end

      it "card links break out of the results frame (so Details opens the show page)" do
        get features_path, headers: frame_headers
        expect(response.body).to include('data-turbo-frame="_top"')
      end

      it "renders collapsible cards with a bulk expand/collapse toggle" do
        get features_path, headers: frame_headers
        expect(response.body).to include('data-controller="expandable-card"')
        expect(response.body).to include("expandable-cards#toggleAll")
      end

      it "filters by a search query across name/summary" do
        get features_path, params: { query: "Admin-only" }, headers: frame_headers
        expect(response.body).to include("Admin-only feature")
        expect(response.body).not_to include("Facilitator feature")
      end

      it "sorts by date released, newest first, by default" do
        user_facing.update!(released_on: 2.days.ago)
        admin_facing.update!(released_on: 1.day.ago)
        get features_path, headers: frame_headers
        expect(response.body.index("Admin-only feature")).to be < response.body.index("Facilitator feature")
      end

      it "sorts by date logged when chosen, ahead of date released" do
        user_facing.update!(released_on: 1.day.ago, created_at: 3.days.ago)
        admin_facing.update!(released_on: 2.days.ago, created_at: 1.day.ago)
        get features_path, params: { logged_direction: "desc" }, headers: frame_headers
        expect(response.body.index("Admin-only feature")).to be < response.body.index("Facilitator feature")

        get features_path, params: { logged_direction: "asc" }, headers: frame_headers
        expect(response.body.index("Facilitator feature")).to be < response.body.index("Admin-only feature")
      end

      it "shows the logged date and labels the release date when sorting by date logged" do
        user_facing.update!(released_on: Date.new(2026, 10, 5), created_at: Time.zone.local(2026, 10, 8, 12))
        get features_path, params: { logged_direction: "desc" }, headers: frame_headers
        expect(response.body).to include("Logged Oct 8, 2026")
        expect(response.body).to match(/Released\s+Oct 5, 2026/)
      end

      it "shows only the unlabeled release date when sorting by date released" do
        user_facing.update!(released_on: Date.new(2026, 10, 5))
        get features_path, headers: frame_headers
        expect(response.body).to include("Oct 5, 2026")
        expect(response.body).not_to include("Logged ")
        expect(response.body).not_to match(/Released\s+Oct 5, 2026/)
      end

      it "ignores an unrecognized date-logged direction" do
        get features_path, params: { logged_direction: "sideways" }, headers: frame_headers
        expect(response).to have_http_status(:ok)
      end

      it "filters by audience" do
        get features_path, params: { display_status: "admin_facing" }, headers: frame_headers
        expect(response.body).to include("Admin-only feature")
        expect(response.body).not_to include("Facilitator feature")
      end

      context "filtering by creator" do
        let(:other_admin) { create(:user, :admin) }
        let!(:by_admin) { create(:feature, name: "Logged by admin", created_by: admin) }
        let!(:by_other_admin) { create(:feature, name: "Logged by other admin", created_by: other_admin) }
        let!(:by_regular_user) { create(:feature, name: "Logged by regular user", created_by: regular_user) }

        it "narrows to one creator" do
          get features_path, params: { created_by: admin.id }, headers: frame_headers
          expect(response.body).to include("Logged by admin")
          expect(response.body).not_to include("Logged by other admin")
          expect(response.body).not_to include("Facilitator feature")
        end

        it "narrows to features any admin created" do
          get features_path, params: { created_by: "admins" }, headers: frame_headers
          expect(response.body).to include("Logged by admin", "Logged by other admin")
          expect(response.body).not_to include("Logged by regular user")
          expect(response.body).not_to include("Facilitator feature")
        end
      end
    end
  end

  describe "the creator filter dropdown" do
    let!(:by_admin) { create(:feature, name: "Logged by admin", created_by: admin) }

    it "offers Any, Admins, and each creator" do
      sign_in regular_user
      get features_path
      expect(response.body).to include('name="created_by"', ">Any<", ">Admins<", admin.full_name)
    end
  end

  describe "GET /features/:id" do
    context "as a regular user" do
      before { sign_in regular_user }

      it "shows a published, non-admin-facing feature" do
        get feature_path(user_facing)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Facilitator feature")
      end

      it "blocks an admin-facing feature" do
        get feature_path(admin_facing)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows an admin-facing feature" do
        get feature_path(admin_facing)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin-only feature")
      end
    end

    context "the creator" do
      let!(:with_creator) { create(:feature, name: "Has a creator", created_by: admin) }

      it "is shown on the detail page" do
        sign_in regular_user
        get feature_path(with_creator)
        expect(response.body).to include("Added by", admin.full_name)
      end

      it "is omitted when the feature has no creator" do
        sign_in regular_user
        get feature_path(user_facing)
        expect(response.body).not_to include("Added by")
      end
    end

    context "the pull-request link" do
      let!(:with_pr) do
        create(:feature, name: "Has a PR", display_status: "user_facing", published: true, pr_number: 2170)
      end

      it "is shown to an admin" do
        sign_in admin
        get feature_path(with_pr)
        expect(response.body).to include("View the pull request")
      end

      it "is hidden from a regular user" do
        sign_in regular_user
        get feature_path(with_pr)
        expect(response.body).not_to include("View the pull request")
      end
    end
  end

  describe "POST /features" do
    let(:valid_attributes) do
      { name: "Brand new", area: "events", display_status: "user_facing",
        summary: "Something useful.", released_on: "2026-08-11" }
    end

    it "lets an admin create a feature" do
      sign_in admin
      expect { post features_path, params: { feature: valid_attributes } }.to change(Feature, :count).by(1)
      expect(response).to redirect_to(Feature.find_by(name: "Brand new"))
    end

    it "blocks a regular user" do
      sign_in regular_user
      expect { post features_path, params: { feature: valid_attributes } }.not_to change(Feature, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /features/import" do
    it "hydrates missing features from the seed for an admin" do
      sign_in admin
      expect { post import_features_path }.to change(Feature, :count)
      expect(response).to redirect_to(features_path)
    end

    it "blocks a regular user" do
      sign_in regular_user
      expect { post import_features_path }.not_to change(Feature, :count)
      expect(response).to redirect_to(root_path)
    end
  end
end
