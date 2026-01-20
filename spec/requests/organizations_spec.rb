require "rails_helper"

RSpec.describe "/organizations", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, super_user: true) }

  let!(:project_status) { create(:project_status, name: "Active") }

  let(:valid_attributes) do
    {
      name: "Healing Through Art Organization",
      description: "A community program supporting trauma-informed workshops.",
      start_date: Date.today - 6.months,
      end_date: Date.today + 6.months,
      project_status_id: project_status.id,
      inactive: false,
      notes: "Runs bi-weekly at community centers."
    }
  end

  let(:invalid_attributes) do
    {
      name: "", # required field missing
      description: nil,
      project_status_id: nil
    }
  end

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      Organization.create!(valid_attributes)
      get organizations_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      organization = Organization.create!(valid_attributes)
      get organization_url(organization)
      expect(response).to be_successful
    end
  end

  describe "GET /annual_evaluations" do
    let(:organization) { Organization.create!(valid_attributes) }
    let(:form_builder) { create(:form_builder, name: "Annual Evaluation") }
    let(:form) { create(:form, owner: form_builder) }

    before do
      create(:project_user, project: organization, user: user)
    end

    it "renders a successful response" do
      get annual_evaluations_organization_url(organization)
      expect(response).to be_successful
    end

    it "accepts year parameter" do
      get annual_evaluations_organization_url(organization, year: 2025)
      expect(response).to be_successful
      expect(assigns(:year)).to eq(2025)
    end

    it "defaults to current year when year parameter is not provided" do
      get annual_evaluations_organization_url(organization)
      expect(response).to be_successful
      expect(assigns(:year)).to eq(Date.current.year)
    end

    it "assigns aggregated responses" do
      get annual_evaluations_organization_url(organization, year: 2025)
      expect(assigns(:aggregated_responses)).to be_present
    end

    it "assigns available years" do
      get annual_evaluations_organization_url(organization)
      expect(assigns(:available_years)).to be_an(Array)
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_organization_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      organization = Organization.create!(valid_attributes)
      get edit_organization_url(organization)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Organization" do
        expect {
          post organizations_url, params: { organization: valid_attributes }
        }.to change(Organization, :count).by(1)
      end

      it "redirects to the created organization" do
        post organizations_url, params: { organization: valid_attributes }
        expect(response).to redirect_to(organization_url(Organization.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Organization" do
        expect {
          post organizations_url, params: { organization: invalid_attributes }
        }.not_to change(Organization, :count)
      end

      it "renders a response with 422 status" do
        post organizations_url, params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /update" do
    let(:organization) { Organization.create!(valid_attributes) }

    context "with valid parameters" do
      let(:new_attributes) do
        { name: "Updated Organization Name" }
      end

      it "updates the requested organization" do
        patch organization_url(organization), params: { organization: new_attributes }
        organization.reload
        expect(organization.name).to eq("Updated Organization Name")
      end

      it "redirects to the organization" do
        patch organization_url(organization), params: { organization: new_attributes }
        organization.reload
        expect(response).to redirect_to(organization_url(organization))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        patch organization_url(organization), params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested organization" do
      organization = Organization.create!(valid_attributes)
      expect {
        delete organization_url(organization)
      }.to change(Organization, :count).by(-1)
    end

    it "redirects to the organizations list" do
      organization = Organization.create!(valid_attributes)
      delete organization_url(organization)
      expect(response).to redirect_to(organizations_url)
    end
  end
end
