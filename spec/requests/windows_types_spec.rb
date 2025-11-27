require 'rails_helper'

RSpec.describe "/windows_types", type: :request do
  # --- VALID + INVALID PARAMS -------------------------------------------------
  let(:valid_attributes) { { name: "Windows Type A", short_name: "WTA", legacy_id: 100 } }
  let(:invalid_attributes) { { name: "", # invalid because required
                               short_name: nil   } } # invalid because required
  let(:new_attributes) { { name: "Updated Name", short_name: "UPD"} }

  before do
    sign_in create(:user, :admin)
  end

  # --- INDEX ------------------------------------------------------------------

  describe "GET /index" do
    it "renders a successful response" do
      WindowsType.create!(valid_attributes)
      get windows_types_url
      expect(response).to be_successful
    end
  end

  # --- SHOW -------------------------------------------------------------------

  describe "GET /show" do
    it "renders a successful response" do
      windows_type = WindowsType.create!(valid_attributes)
      get windows_type_url(windows_type)
      expect(response).to be_successful
    end
  end

  # --- NEW -------------------------------------------------------------------

  describe "GET /new" do
    it "renders a successful response" do
      get new_windows_type_url
      expect(response).to be_successful
    end
  end

  # --- EDIT ------------------------------------------------------------------

  describe "GET /edit" do
    it "renders a successful response" do
      windows_type = WindowsType.create!(valid_attributes)
      get edit_windows_type_url(windows_type)
      expect(response).to be_successful
    end
  end

  # --- CREATE ----------------------------------------------------------------

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new WindowsType" do
        expect {
          post windows_types_url, params: { windows_type: valid_attributes }
        }.to change(WindowsType, :count).by(1)
      end

      it "redirects to the created windows_type" do
        post windows_types_url, params: { windows_type: valid_attributes }
        expect(response).to redirect_to(windows_types_url)
      end
    end

    context "with invalid parameters" do
      it "does not create a new WindowsType" do
        expect {
          post windows_types_url, params: { windows_type: invalid_attributes }
        }.not_to change(WindowsType, :count)
      end

      it "renders unprocessable_content" do
        post windows_types_url, params: { windows_type: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # --- UPDATE ----------------------------------------------------------------

  describe "PATCH /update" do
    context "with valid parameters" do
      it "updates the requested windows_type" do
        windows_type = WindowsType.create!(valid_attributes)
        patch windows_type_url(windows_type), params: { windows_type: new_attributes }
        windows_type.reload

        expect(windows_type.name).to eq("Updated Name")
        expect(windows_type.short_name).to eq("UPD")
      end

      it "redirects to the windows_type" do
        windows_type = WindowsType.create!(valid_attributes)
        patch windows_type_url(windows_type), params: { windows_type: new_attributes }
        expect(response).to redirect_to(windows_types_url)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        windows_type = WindowsType.create!(valid_attributes)
        patch windows_type_url(windows_type), params: { windows_type: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # --- DESTROY ---------------------------------------------------------------

  describe "DELETE /destroy" do
    it "destroys the requested windows_type" do
      windows_type = WindowsType.create!(valid_attributes)

      expect {
        delete windows_type_url(windows_type)
      }.to change(WindowsType, :count).by(-1)
    end

    it "redirects to the windows_types list" do
      windows_type = WindowsType.create!(valid_attributes)
      delete windows_type_url(windows_type)
      expect(response).to redirect_to(windows_types_url)
    end
  end
end
