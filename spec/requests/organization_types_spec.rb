require 'rails_helper'

RSpec.describe "/organization_types", type: :request do
  let(:valid_attributes) do
    {
      name: "Test Organization Type",
      published: true
    }
  end

  let(:invalid_attributes) do
    {
      name: "",
      published: nil
    }
  end

  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      OrganizationType.create! valid_attributes
      get organization_types_url
      expect(response).to be_successful
    end

    context "filtering" do
      let!(:organization_types) do
        [
          create(:organization_type, name: "Type1", published: true),
          create(:organization_type, name: "Type2", published: true),
          create(:organization_type, name: "Type3", published: false),
          create(:organization_type, name: "Type4", published: false)
        ]
      end

      it "returns all organization types without filters" do
        get organization_types_url
        organization_types.each { |type| expect(response.body).to include(type.name) }
      end

      it "returns only published organization types when published=true" do
        get organization_types_url, params: { published: "true" }
        expect(response.body).to include("Type1", "Type2")
        expect(response.body).not_to include("Type3")
        expect(response.body).not_to include("Type4")
      end

      it "returns only unpublished organization types when published=false" do
        get organization_types_url, params: { published: "false" }
        expect(response.body).to include("Type3", "Type4")
        expect(response.body).not_to include("Type1")
        expect(response.body).not_to include("Type2")
      end

      it "filters by name" do
        get organization_types_url, params: { name: "Type1" }
        expect(response.body).to include("Type1")
        expect(response.body).not_to include("Type2")
      end
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      organization_type = OrganizationType.create! valid_attributes
      get organization_type_url(organization_type)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_organization_type_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      organization_type = OrganizationType.create! valid_attributes
      get edit_organization_type_url(organization_type)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new OrganizationType" do
        expect {
          post organization_types_url, params: { organization_type: valid_attributes }
        }.to change(OrganizationType, :count).by(1)
      end

      it "redirects to the created organization type" do
        post organization_types_url, params: { organization_type: valid_attributes }
        expect(response).to redirect_to(organization_type_url(OrganizationType.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new OrganizationType" do
        expect {
          post organization_types_url, params: { organization_type: invalid_attributes }
        }.to change(OrganizationType, :count).by(0)
      end

      it "renders a response with 422 status" do
        post organization_types_url, params: { organization_type: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        valid_attributes.merge(
          name: "Updated Type Name",
          description: "Clarifying subtext for this type"
        )
      end

      it "updates the requested organization type" do
        organization_type = OrganizationType.create! valid_attributes
        patch organization_type_url(organization_type), params: { organization_type: new_attributes }
        organization_type.reload
        expect(organization_type.name).to eq("Updated Type Name")
        expect(organization_type.description).to eq("Clarifying subtext for this type")
      end

      it "redirects to the organization type" do
        organization_type = OrganizationType.create! valid_attributes
        patch organization_type_url(organization_type), params: { organization_type: new_attributes }
        expect(response).to redirect_to(organization_type_url(organization_type))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        organization_type = OrganizationType.create! valid_attributes
        patch organization_type_url(organization_type), params: { organization_type: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested organization type" do
      organization_type = OrganizationType.create! valid_attributes
      expect {
        delete organization_type_url(organization_type)
      }.to change(OrganizationType, :count).by(-1)
    end

    it "redirects to the organization types list" do
      organization_type = OrganizationType.create! valid_attributes
      delete organization_type_url(organization_type)
      expect(response).to redirect_to(organization_types_url)
    end

    it "nullifies the type on organizations that referenced it" do
      organization_type = OrganizationType.create! valid_attributes
      organization = create(:organization, organization_type: organization_type)
      delete organization_type_url(organization_type)
      expect(organization.reload.organization_type_id).to be_nil
    end
  end
end
