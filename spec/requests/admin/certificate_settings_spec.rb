require "rails_helper"

RSpec.describe "Admin::CertificateSettings", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:image) { fixture_file_upload("spec/fixtures/files/sample.png", "image/png") }

  describe "GET show" do
    before { sign_in admin }

    it "renders an upload spot for each frame and signature" do
      get admin_certificate_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Live training frame")
      expect(response.body).to include("On-demand training frame")
      expect(response.body).to include("Other events frame")
      expect(response.body).to include("Training signatures")
      expect(response.body).to include("CE certificate signature")
    end

    it "previews an already-uploaded frame" do
      resource = create(:resource, title: Resource::CERTIFICATE_FRAME_TITLES[:training], hidden_from_search: true)
      create(:primary_asset, :with_file, owner: resource)

      get admin_certificate_settings_path

      expect(response.body).to include("Replace")
    end
  end

  describe "PATCH update" do
    before { sign_in admin }

    it "creates a hidden resource and attaches the uploaded frame" do
      patch admin_certificate_settings_path, params: { slot: "training_frame", file: image }

      expect(response).to redirect_to(admin_certificate_settings_path)
      resource = Resource.find_by(title: Resource::CERTIFICATE_FRAME_TITLES[:training])
      expect(resource).to be_present
      expect(resource.hidden_from_search).to be(true)
      expect(resource.signature_file).to be_attached
    end

    it "attaches the training signature strip to its own slot" do
      patch admin_certificate_settings_path, params: { slot: "training_signatures", file: image }

      resource = Resource.find_by(title: Resource::TRAINING_CERTIFICATE_SIGNATURES_TITLE)
      expect(resource.signature_file).to be_attached
    end

    it "attaches the CE signature to its own slot" do
      patch admin_certificate_settings_path, params: { slot: "ce_signatures", file: image }

      resource = Resource.find_by(title: Resource::CE_CERTIFICATE_SIGNATURE_TITLE)
      expect(resource.signature_file).to be_attached
    end

    it "removes an uploaded frame" do
      resource = create(:resource, title: Resource::CERTIFICATE_FRAME_TITLES[:other], hidden_from_search: true)
      create(:primary_asset, :with_file, owner: resource)

      patch admin_certificate_settings_path, params: { slot: "other_frame", remove: "1" }

      expect(response).to redirect_to(admin_certificate_settings_path)
      expect(resource.reload.primary_asset.file).not_to be_attached
    end

    it "rejects an unknown slot rather than erroring" do
      patch admin_certificate_settings_path, params: { slot: "bogus", file: image }

      expect(response).to redirect_to(admin_certificate_settings_path)
      expect(flash[:alert]).to eq("Unknown setting.")
    end

    it "asks for a file when none is given" do
      patch admin_certificate_settings_path, params: { slot: "training_frame" }

      expect(flash[:alert]).to eq("Choose an image to upload.")
    end
  end

  describe "authorization" do
    it "denies a non-admin the page" do
      sign_in create(:user)

      get admin_certificate_settings_path

      expect(response).not_to have_http_status(:ok)
    end

    it "denies a non-admin an upload, storing nothing" do
      sign_in create(:user)

      patch admin_certificate_settings_path, params: { slot: "training_frame", file: image }

      expect(response).not_to have_http_status(:ok)
      expect(Resource.find_by(title: Resource::CERTIFICATE_FRAME_TITLES[:training])).to be_nil
    end
  end
end
