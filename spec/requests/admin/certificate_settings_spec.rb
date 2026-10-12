require "rails_helper"

RSpec.describe "Admin::CertificateSettings", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET show" do
    before { sign_in admin }

    it "renders a connect spot for each frame and signature" do
      get admin_certificate_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Facilitator training frame")
      expect(response.body).to include("On-demand training frame")
      expect(response.body).to include("CE certificate frame")
      expect(response.body).to include("Other events frame")
      expect(response.body).to include("Facilitator training signatures")
      expect(response.body).to include("CE certificate signature")
    end

    it "shows the exact auto-match Resource title for each slot" do
      get admin_certificate_settings_path

      expect(response.body).to include(Resource::TRAINING_CERTIFICATE_SIGNATURES_TITLE)
      expect(response.body).to include(Resource::CE_CERTIFICATE_SIGNATURE_TITLE)
      expect(response.body).to include(Resource::CERTIFICATE_FRAME_TITLES[:training])
    end

    it "renders a live mini-preview of the final certificate with sample content" do
      get admin_certificate_settings_path

      expect(response.body).to include("Jordan Rivera")
      expect(response.body).to include("Spring Facilitator Training")
      expect(response.body).to include("certificate-training-border")
    end

    it "previews the connected resource and offers reconnect" do
      resource = create(:resource, title: "Training frame art", certificate_role: "training_frame")
      create(:primary_asset, :with_file, owner: resource)

      get admin_certificate_settings_path

      expect(response.body).to include("Training frame art")
      expect(response.body).to include("Reconnect")
    end
  end

  describe "PATCH update" do
    before { sign_in admin }

    it "connects the chosen resource to the slot" do
      resource = create(:resource)

      patch admin_certificate_settings_path, params: { slot: "training_frame", resource_id: resource.id }

      expect(response).to redirect_to(admin_certificate_settings_path)
      expect(response).to have_http_status(:see_other)
      expect(resource.reload.certificate_role).to eq("training_frame")
    end

    it "connects a resource to the CE frame slot" do
      resource = create(:resource)

      patch admin_certificate_settings_path, params: { slot: "ce_frame", resource_id: resource.id }

      expect(resource.reload.certificate_role).to eq("ce_frame")
    end

    it "connects the signature strips to their own slots" do
      training = create(:resource)
      ce = create(:resource)

      patch admin_certificate_settings_path, params: { slot: "training_signatures", resource_id: training.id }
      patch admin_certificate_settings_path, params: { slot: "ce_signatures", resource_id: ce.id }

      expect(training.reload.certificate_role).to eq("training_signatures")
      expect(ce.reload.certificate_role).to eq("ce_signatures")
    end

    it "clears the previous holder when reassigning a slot" do
      old = create(:resource, certificate_role: "other_frame")
      new_resource = create(:resource)

      patch admin_certificate_settings_path, params: { slot: "other_frame", resource_id: new_resource.id }

      expect(old.reload.certificate_role).to be_nil
      expect(new_resource.reload.certificate_role).to eq("other_frame")
    end

    it "disconnects a slot" do
      resource = create(:resource, certificate_role: "other_frame")

      patch admin_certificate_settings_path, params: { slot: "other_frame", remove: "1" }

      expect(response).to redirect_to(admin_certificate_settings_path)
      expect(response).to have_http_status(:see_other)
      expect(resource.reload.certificate_role).to be_nil
    end

    it "rejects an unknown slot rather than erroring" do
      resource = create(:resource)

      patch admin_certificate_settings_path, params: { slot: "bogus", resource_id: resource.id }

      expect(response).to redirect_to(admin_certificate_settings_path)
      expect(flash[:alert]).to eq("Unknown setting.")
      expect(resource.reload.certificate_role).to be_nil
    end

    it "asks for a resource when none is chosen" do
      patch admin_certificate_settings_path, params: { slot: "training_frame" }

      expect(flash[:alert]).to eq("Choose a resource to connect.")
    end
  end

  describe "authorization" do
    it "denies a non-admin the page" do
      sign_in create(:user)

      get admin_certificate_settings_path

      expect(response).not_to have_http_status(:ok)
    end

    it "denies a non-admin a connect, changing nothing" do
      resource = create(:resource)
      sign_in create(:user)

      patch admin_certificate_settings_path, params: { slot: "training_frame", resource_id: resource.id }

      expect(response).not_to have_http_status(:ok)
      expect(resource.reload.certificate_role).to be_nil
    end
  end
end
