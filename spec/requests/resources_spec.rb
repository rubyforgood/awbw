require "rails_helper"

RSpec.describe "/resources", type: :request do
  let(:user)         { create(:user, super_user: true) }
  let(:windows_type) { create(:windows_type) }
  let(:organization) { create(:organization) }

  let(:valid_attributes) do
    {
      title: "Helpful Resource",
      body: "This is a very helpful resource.",
      url: "https://www.example.com",
      published: true,
      kind: Resource::PUBLISHED_KINDS.first,
      windows_type_id: windows_type.id,
      created_by_id: user.id
    }
  end

  let(:invalid_attributes) do
    {
      title: nil,
      body: "",
      kind: nil,
      created_by_id: user.id      # REQUIRED
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

  describe "GET /index search results filtering" do
    let!(:visible_resource) do
      create(:resource, :publicly_visible, :published, title: "Visible In Search")
    end
    let!(:hidden_resource) do
      create(:resource, :publicly_visible, :published, :hidden_from_search, title: "Hidden From Search")
    end

    it "includes hidden resources for an admin" do
      get resources_url, headers: { "Turbo-Frame" => "resources_results" }

      expect(response.body).to include("Visible In Search")
      expect(response.body).to include("Hidden From Search")
    end

    it "excludes hidden resources for a guest" do
      sign_out user
      get resources_url, headers: { "Turbo-Frame" => "resources_results" }

      expect(response.body).to include("Visible In Search")
      expect(response.body).not_to include("Hidden From Search")
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

      it "relaxes object-src to :self for the PDF <object> preview" do
        get resource_url(resource)

        expect(response.headers["Content-Security-Policy-Report-Only"]).to include("object-src 'self'")
      end
    end
  end

  describe "GET /index (non-preview action)" do
    it "keeps the strict global object-src 'none'" do
      get resources_url

      expect(response.headers["Content-Security-Policy-Report-Only"]).to include("object-src 'none'")
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

    it "renders the visibility flags, including hidden from search, with definitions" do
      resource = Resource.create! valid_attributes
      get edit_resource_url(resource)

      expect(response.body).to include('name="resource[hidden_from_search]"')
      expect(response.body).to include('name="resource[publicly_visible]"')
      expect(response.body).to include(VisibilityFlagsHelper::FLAG_DEFINITIONS[:hidden_from_search][:description])
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Resource" do
        expect {
          post resources_url, params: { resource: valid_attributes }
        }.to change(Resource, :count).by(1)
      end

      it "redirects to the created resource" do
        post resources_url, params: { resource: valid_attributes }

        expect(response).to redirect_to(resource_url(Resource.last))
      end

      it "credits the chosen person as author and records the creator" do
        facilitator = create(:person)

        post resources_url, params: { resource: valid_attributes.merge(author_id: facilitator.id) }

        resource = Resource.last
        expect(resource.author).to eq(facilitator)
        expect(resource.created_by).to eq(user)
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

      it "redirects to the updated resource" do
        resource = Resource.create! valid_attributes
        patch resource_url(resource), params: { resource: new_attributes }

        expect(response).to redirect_to(resource_url(resource))
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
