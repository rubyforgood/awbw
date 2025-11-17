require "rails_helper"

RSpec.describe "/projects", type: :request do

  let(:user) { create(:user) }
  let(:admin) { create(:user, super_user: true) }

  let!(:location) { create(:location) }
  let!(:project_status) { create(:project_status, name: "Active") }

  let(:valid_attributes) do
    {
      name: "Healing Through Art",
      description: "A community program supporting trauma-informed workshops.",
      start_date: Date.today - 6.months,
      end_date: Date.today + 6.months,
      project_status_id: project_status.id,
      inactive: false,
      notes: "Runs bi-weekly at community centers.",
    }
  end

  let(:invalid_attributes) do
    {
      name: "", # required field missing
      description: nil,
      project_status_id: nil,
      windows_type_id: nil,
    }
  end

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      Project.create!(valid_attributes)
      get projects_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      project = Project.create!(valid_attributes)
      get project_url(project)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_project_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      project = Project.create!(valid_attributes)
      get edit_project_url(project)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Project" do
        expect {
          post projects_url, params: { project: valid_attributes }
        }.to change(Project, :count).by(1)
      end

      it "redirects to the projects index" do
        post projects_url, params: { project: valid_attributes }
        expect(response).to redirect_to(projects_url)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Project" do
        expect {
          post projects_url, params: { project: invalid_attributes }
        }.not_to change(Project, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post projects_url, params: { project: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        {
          name: "Updated Healing Project",
          description: "Updated description for testing.",
          inactive: true
        }
      end

      it "updates the requested project" do
        project = Project.create!(valid_attributes)
        patch project_url(project), params: { project: new_attributes }
        project.reload
        expect(project.name).to eq("Updated Healing Project")
        expect(project.description).to eq("Updated description for testing.")
        expect(project.inactive).to be(true)
      end

      it "redirects to the projects index" do
        project = Project.create!(valid_attributes)
        patch project_url(project), params: { project: new_attributes }
        expect(response).to redirect_to(projects_url)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        project = Project.create!(valid_attributes)
        patch project_url(project), params: { project: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested project" do
      project = Project.create!(valid_attributes)
      expect {
        delete project_url(project)
      }.to change(Project, :count).by(-1)
    end

    it "redirects to the projects list" do
      project = Project.create!(valid_attributes)
      delete project_url(project)
      expect(response).to redirect_to(projects_url)
    end
  end
end
