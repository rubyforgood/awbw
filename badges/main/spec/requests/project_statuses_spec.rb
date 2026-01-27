require "rails_helper"

RSpec.describe "/project_statuses", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:valid_attributes) do
    { name: "Active" }
  end

  let(:invalid_attributes) do
    { name: nil }
  end

  # --------------------------------------------------
  # ADMIN ACCESS
  # --------------------------------------------------
  describe "admin access" do
    before { sign_in admin }

    describe "GET /index" do
      it "renders successfully" do
        get project_statuses_url
        expect(response).to be_successful
      end
    end

    describe "GET /show" do
      it "renders successfully" do
        project_status = ProjectStatus.create!(valid_attributes)
        get project_status_url(project_status)
        expect(response).to be_successful
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_project_status_url
        expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders successfully" do
        project_status = ProjectStatus.create!(valid_attributes)
        get edit_project_status_url(project_status)
        expect(response).to be_successful
      end
    end

    describe "POST /create" do
      context "with valid params" do
        it "creates a ProjectStatus" do
          expect {
            post project_statuses_url, params: { project_status: valid_attributes }
          }.to change(ProjectStatus, :count).by(1)
        end

        it "redirects to index" do
          post project_statuses_url, params: { project_status: valid_attributes }
          expect(response).to redirect_to(project_statuses_url)
        end
      end

      context "with invalid params" do
        it "does not create a ProjectStatus" do
          expect {
            post project_statuses_url, params: { project_status: invalid_attributes }
          }.not_to change(ProjectStatus, :count)
        end

        it "returns 422" do
          post project_statuses_url, params: { project_status: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "PATCH /update" do
      it "updates and redirects" do
        project_status = ProjectStatus.create!(valid_attributes)

        patch project_status_url(project_status),
              params: { project_status: { name: "Updated" } }

        expect(response).to redirect_to(project_statuses_url)
        expect(project_status.reload.name).to eq("Updated")
      end
    end

    describe "DELETE /destroy" do
      it "destroys and redirects" do
        project_status = ProjectStatus.create!(valid_attributes)

        expect {
          delete project_status_url(project_status)
        }.to change(ProjectStatus, :count).by(-1)

        expect(response).to redirect_to(project_statuses_url)
      end
    end
  end

  # --------------------------------------------------
  # REGULAR USER ACCESS (BLOCKED)
  # --------------------------------------------------
  describe "regular user restrictions" do
    before { sign_in regular_user }

    it "cannot access index" do
      get project_statuses_url
      expect(response).to redirect_to(root_path)
    end

    it "cannot access show" do
      ps = ProjectStatus.create!(valid_attributes)
      get project_status_url(ps)
      expect(response).to redirect_to(root_path)
    end

    it "cannot access new" do
      get new_project_status_url
      expect(response).to redirect_to(root_path)
    end

    it "cannot create" do
      post project_statuses_url, params: { project_status: valid_attributes }
      expect(response).to redirect_to(root_path)
    end

    it "cannot edit" do
      ps = ProjectStatus.create!(valid_attributes)
      get edit_project_status_url(ps)
      expect(response).to redirect_to(root_path)
    end

    it "cannot destroy" do
      ps = ProjectStatus.create!(valid_attributes)
      delete project_status_url(ps)
      expect(response).to redirect_to(root_path)
    end
  end

  # --------------------------------------------------
  # UNAUTHENTICATED ACCESS (BLOCKED)
  # --------------------------------------------------
  describe "unauthenticated access" do
    it "redirects to sign-in" do
      get project_statuses_url
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
