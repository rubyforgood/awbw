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

      it "redirects to sectors index" do
        post sectors_url, params: { sector: valid_attributes }
        expect(response).to redirect_to(sectors_url)
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
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested sector" do
        sector = Sector.create! valid_attributes
        patch sector_url(sector), params: { sector: new_attributes }
        sector.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the sectors index" do
        sector = Sector.create! valid_attributes
        patch sector_url(sector), params: { sector: new_attributes }
        sector.reload
        expect(response).to redirect_to(sectors_url)
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
