require "rails_helper"

RSpec.describe "/resources", type: :request do
  let(:user)         { create(:user) }
  let(:windows_type) { create(:windows_type) }
  let(:project)      { create(:project) }

  let(:valid_attributes) do
    {
      title: "Helpful Resource",
      text: "This is a very helpful resource.",
      url: "https://www.example.com",
      inactive: false,
      kind: Resource::PUBLISHED_KINDS.first,
      windows_type_id: windows_type.id,
      user_id: user.id,
    }
  end

  let(:invalid_attributes) do
    {
      title: nil,
      text: "",
      kind: nil,
      user_id: user.id      # REQUIRED
    }
  end

  before do
    sign_in user
  end

  describe "GET /index" do
    it "renders a successful response" do
      Resource.create! valid_attributes
      get resources_url

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /show" do
    context "when resource has NO external link" do
      let(:resource) do
        Resource.create!(valid_attributes.merge(url: nil))
      end

      it "renders the show page" do
        get resource_url(resource)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when resource HAS an external link" do
      let(:resource) do
        Resource.create!(
          valid_attributes.merge(url: "www.google.com")
        )
      end

      it "redirects to the external URL" do
        get resource_url(resource)

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to("https://www.google.com")
      end
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_resource_url

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      resource = Resource.create! valid_attributes
      get edit_resource_url(resource)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Resource" do
        expect {
          post resources_url, params: { resource: valid_attributes }
        }.to change(Resource, :count).by(1)
      end

      it "redirects to the resources index" do
        post resources_url, params: { resource: valid_attributes }

        expect(response).to redirect_to(resources_url)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Resource" do
        expect {
          post resources_url, params: { resource: invalid_attributes }
        }.not_to change(Resource, :count)
      end

      it "renders a response with 422 status" do
        post resources_url, params: { resource: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        valid_attributes.merge(title: "Updated Resource Title")
      end

      it "updates the requested resource" do
        resource = Resource.create! valid_attributes
        patch resource_url(resource), params: { resource: new_attributes }

        resource.reload
        expect(resource.title).to eq("Updated Resource Title")
      end

      it "redirects to the resources index" do
        resource = Resource.create! valid_attributes
        patch resource_url(resource), params: { resource: new_attributes }

        expect(response).to redirect_to(resources_url)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        resource = Resource.create! valid_attributes
        patch resource_url(resource), params: { resource: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested resource" do
      resource = Resource.create! valid_attributes

      expect {
        delete resource_url(resource)
      }.to change(Resource, :count).by(-1)
    end

    it "redirects to the resources list" do
      resource = Resource.create! valid_attributes
      delete resource_url(resource)

      expect(response).to redirect_to(resources_url)
    end
  end
end
