require 'rails_helper'

RSpec.describe "/sectors", type: :request do
  let(:valid_attributes) do
    {
      name: "Test Sector",
      published: true
    }
  end

  let(:invalid_attributes) do
    {
      name: "",                    # invalid: required
      published: nil               # invalid: boolean required
    }
  end

  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      Sector.create! valid_attributes
      get sectors_url
      expect(response).to be_successful
    end

    context "filtering" do
      let!(:sectors) do
        [
          create(:sector, name: "Sector1", published: true),
          create(:sector, name: "Sector2", published: true),
          create(:sector, name: "Sector3", published: false),
          create(:sector, name: "Sector4", published: false)
        ]
      end

      it "returns all sectors without filters" do
        get sectors_url
        sectors.each { |sector| expect(response.body).to include(sector.name) }
      end

      it "returns only published sectors when published=true" do
        get sectors_url, params: { published: "true" }
        expect(response.body).to include("Sector1", "Sector2")
        expect(response.body).not_to include("Sector3")
        expect(response.body).not_to include("Sector4")
      end

      it "returns only unpublished sectors when published=false" do
        get sectors_url, params: { published: "false" }
        expect(response.body).to include("Sector3", "Sector4")
        expect(response.body).not_to include("Sector1")
        expect(response.body).not_to include("Sector2")
      end

      it "filters by name" do
        get sectors_url, params: { sector_name: "Sector1" }
        expect(response.body).to include("Sector1")
        expect(response.body).not_to include("Sector2")
        expect(response.body).not_to include("Sector3")
        expect(response.body).not_to include("Sector4")
      end
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      sector = Sector.create! valid_attributes
      get sector_url(sector)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_sector_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      sector = Sector.create! valid_attributes
      get edit_sector_url(sector)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Sector" do
        expect {
          post sectors_url, params: { sector: valid_attributes }
        }.to change(Sector, :count).by(1)
      end

      it "redirects to the created sector" do
        post sectors_url, params: { sector: valid_attributes }
        expect(response).to redirect_to(sector_url(Sector.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Sector" do
        expect {
          post sectors_url, params: { sector: invalid_attributes }
        }.to change(Sector, :count).by(0)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post sectors_url, params: { sector: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        valid_attributes.merge(
          name: "Updated Sector Name"
        )
      end

      it "updates the requested sector" do
        sector = Sector.create! valid_attributes
        patch sector_url(sector), params: { sector: new_attributes }
        sector.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the sector" do
        sector = Sector.create! valid_attributes
        patch sector_url(sector), params: { sector: new_attributes }
        sector.reload
        expect(response).to redirect_to(sector_url(sector))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        sector = Sector.create! valid_attributes
        patch sector_url(sector), params: { sector: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested sector" do
      sector = Sector.create! valid_attributes
      expect {
        delete sector_url(sector)
      }.to change(Sector, :count).by(-1)
    end

    it "redirects to the sectors list" do
      sector = Sector.create! valid_attributes
      delete sector_url(sector)
      expect(response).to redirect_to(sectors_url)
    end
  end
end
