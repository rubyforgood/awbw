require "rails_helper"

RSpec.describe "/organizations", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:location) { create(:location) }
  let!(:organization_status) { create(:organization_status, name: "Active") }

  let(:valid_attributes) do
    {
      name: "Healing Through Art",
      description: "A community program supporting trauma-informed workshops.",
      start_date: Date.today - 6.months,
      end_date: Date.today + 6.months,
      organization_status_id: organization_status.id,
      notes: "Runs bi-weekly at community centers."
    }
  end

  let(:invalid_attributes) do
    {
      name: "", # required field missing
      description: nil,
      organization_status_id: nil,
      windows_type_id: nil
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

      it "redirects to the organizations index" do
        post organizations_url, params: { organization: valid_attributes }
        expect(response).to redirect_to(organizations_url)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Organization" do
        expect {
          post organizations_url, params: { organization: invalid_attributes }
        }.not_to change(Organization, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post organizations_url, params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        {
          name: "Updated Healing Organization",
          description: "Updated description for testing."
        }
      end

      it "updates the requested organization" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: new_attributes }
        organization.reload
        expect(organization.name).to eq("Updated Healing Organization")
        expect(organization.description).to eq("Updated description for testing.")
      end

      it "redirects to the organizations index" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: new_attributes }
        expect(response).to redirect_to(organizations_url)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        organization = Organization.create!(valid_attributes)
        patch organization_url(organization), params: { organization: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
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
