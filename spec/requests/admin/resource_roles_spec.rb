require "rails_helper"

RSpec.describe "Admin::ResourceRoles", type: :request do
  let(:admin) { create(:user, :admin) }

  after { Current.user = nil }

  describe "GET show" do
    before { sign_in admin }

    it "renders a connect spot for each frame and signature" do
      get admin_resource_roles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Facilitator training frame")
      expect(response.body).to include("On-demand training frame")
      expect(response.body).to include("CE certificate frame")
      expect(response.body).to include("Other events frame")
      expect(response.body).to include("Facilitator training signatures")
      expect(response.body).to include("CE certificate signature")
    end

    it "renders a connect spot for the W-9 and each training handout" do
      get admin_resource_roles_path

      expect(response.body).to include("Payment documents")
      expect(response.body).to include("W-9")
      expect(response.body).to include("Training handouts")
      expect(response.body).to include("Letter to supervisors")
    end

    it "renders a live mini-preview of the final certificate with sample content" do
      get admin_resource_roles_path

      expect(response.body).to include("Jordan Rivera")
      expect(response.body).to include("Spring Facilitator Training")
      expect(response.body).to include("certificate-training-border")
    end

    it "reflects a resource auto-matched by its legacy title" do
      create(:resource, title: Resource::LEGACY_ROLE_TITLES["w9"])

      get admin_resource_roles_path

      expect(response.body).to include("Auto-matched by title")
    end

    it "links to create a Resource for an empty slot" do
      get admin_resource_roles_path

      expect(response.body).to include(new_resource_path(title: "Facilitator training frame"))
    end

    it "offers to open a linked resource in a new tab" do
      resource = create(:resource, role: "training_frame")

      get admin_resource_roles_path

      expect(response.body).to include(edit_resource_path(resource))
    end

    it "preselects the connected resource in the picker" do
      resource = create(:resource, title: "Training frame art", role: "training_frame")
      create(:primary_asset, :with_file, owner: resource)

      get admin_resource_roles_path

      expect(response.body).to include("Training frame art")
    end

    it "links each certificate mini-preview to its full-size preview" do
      get admin_resource_roles_path

      %w[training_frame on_demand_frame ce_frame other_frame].each do |role|
        expect(response.body).to include(admin_resource_role_preview_path(role))
      end
      expect(response.body).not_to include(admin_resource_role_preview_path("training_signatures"))
    end
  end

  describe "GET preview" do
    before { sign_in admin }

    it "renders the full-size certificate with sample content" do
      get admin_resource_role_preview_path("training_frame")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Facilitator training frame")
      expect(response.body).to include("Jordan Rivera")
      expect(response.body).to include("certificate-training-border")
      expect(response.body).to include(admin_resource_roles_path(anchor: "training_frame"))
    end

    it "renders the CE certificate with its sample license" do
      get admin_resource_role_preview_path("ce_frame")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LMFT 00000")
    end

    it "includes the signature the certificate prints with" do
      resource = create(:resource, role: "training_signatures")
      create(:primary_asset, :with_file, owner: resource)

      get admin_resource_role_preview_path("training_frame")

      expect(response.body).to include(resource.signature_file.filename.to_s)
    end

    it "redirects for a slot with no certificate" do
      get admin_resource_role_preview_path("w9")

      expect(response).to redirect_to(admin_resource_roles_path)
    end
  end

  describe "PATCH update" do
    before { sign_in admin }

    it "connects the chosen resource to the slot" do
      resource = create(:resource)

      patch admin_resource_roles_path, params: { slot: "training_frame", resource_id: resource.id }

      expect(response).to redirect_to(admin_resource_roles_path)
      expect(response).to have_http_status(:see_other)
      expect(resource.reload.role).to eq("training_frame")
    end

    it "connects a resource to the W-9 slot" do
      resource = create(:resource)

      patch admin_resource_roles_path, params: { slot: "w9", resource_id: resource.id }

      expect(resource.reload.role).to eq("w9")
    end

    it "connects a resource to the CE frame slot" do
      resource = create(:resource)

      patch admin_resource_roles_path, params: { slot: "ce_frame", resource_id: resource.id }

      expect(resource.reload.role).to eq("ce_frame")
    end

    it "connects the signature strips to their own slots" do
      training = create(:resource)
      ce = create(:resource)

      patch admin_resource_roles_path, params: { slot: "training_signatures", resource_id: training.id }
      patch admin_resource_roles_path, params: { slot: "ce_signatures", resource_id: ce.id }

      expect(training.reload.role).to eq("training_signatures")
      expect(ce.reload.role).to eq("ce_signatures")
    end

    it "clears the previous holder when reassigning a slot" do
      old = create(:resource, role: "other_frame")
      new_resource = create(:resource)

      patch admin_resource_roles_path, params: { slot: "other_frame", resource_id: new_resource.id }

      expect(old.reload.role).to be_nil
      expect(new_resource.reload.role).to eq("other_frame")
    end

    it "disconnects a slot" do
      resource = create(:resource, role: "other_frame")

      patch admin_resource_roles_path, params: { slot: "other_frame", remove: "1" }

      expect(response).to redirect_to(admin_resource_roles_path)
      expect(response).to have_http_status(:see_other)
      expect(resource.reload.role).to be_nil
    end

    it "treats a cleared (blank) picker as a disconnect" do
      resource = create(:resource, role: "other_frame")

      patch admin_resource_roles_path, params: { slot: "other_frame", resource_id: "" }

      expect(response).to redirect_to(admin_resource_roles_path)
      expect(resource.reload.role).to be_nil
    end

    context "when a resource fails validations unrelated to its role" do
      let(:legacy) do
        create(:resource, title: "Legacy W-9").tap do |resource|
          resource.update_columns(created_by_id: nil, updated_by_id: nil, kind: nil)
        end
      end

      it "still connects it, stamping updated_by and the blank created_by" do
        patch admin_resource_roles_path, params: { slot: "w9", resource_id: legacy.id }

        expect(response).to redirect_to(admin_resource_roles_path)
        legacy.reload
        expect(legacy.role).to eq("w9")
        expect(legacy.updated_by).to eq(admin)
        expect(legacy.created_by).to eq(admin)
      end

      it "keeps an existing created_by" do
        creator = create(:user)
        legacy.update_columns(created_by_id: creator.id)

        patch admin_resource_roles_path, params: { slot: "w9", resource_id: legacy.id }

        expect(legacy.reload.created_by).to eq(creator)
      end

      it "still reassigns the slot away from it" do
        legacy.update_columns(role: "w9")
        replacement = create(:resource)

        patch admin_resource_roles_path, params: { slot: "w9", resource_id: replacement.id }

        expect(legacy.reload.role).to be_nil
        expect(legacy.updated_by).to eq(admin)
        expect(replacement.reload.role).to eq("w9")
      end

      it "still disconnects it" do
        legacy.update_columns(role: "w9")

        patch admin_resource_roles_path, params: { slot: "w9", remove: "1" }

        expect(legacy.reload.role).to be_nil
      end
    end

    it "records the role change on the resource's change log" do
      resource = create(:resource)
      Analytics::LifecycleBuffer.store.clear
      events = []
      allow(Analytics::LifecycleBuffer).to receive(:flush) do
        events.concat(Analytics::LifecycleBuffer.store)
        Analytics::LifecycleBuffer.store.clear
      end

      patch admin_resource_roles_path, params: { slot: "w9", resource_id: resource.id }

      event = events.find { |e| e[:name] == "update.resource" }
      expect(event.dig(:properties, :changes, "role")).to eq(before: nil, after: "w9")
    end

    it "asks to retry when another admin claims the slot at the same moment" do
      resource = create(:resource)
      allow_any_instance_of(Resource).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

      patch admin_resource_roles_path, params: { slot: "w9", resource_id: resource.id }

      expect(response).to redirect_to(admin_resource_roles_path)
      expect(flash[:alert]).to eq("That slot just changed. Please try again.")
    end

    it "rejects an unknown slot rather than erroring" do
      resource = create(:resource)

      patch admin_resource_roles_path, params: { slot: "bogus", resource_id: resource.id }

      expect(response).to redirect_to(admin_resource_roles_path)
      expect(flash[:alert]).to eq("Unknown setting.")
      expect(resource.reload.role).to be_nil
    end

    it "alerts when the chosen resource no longer exists" do
      patch admin_resource_roles_path, params: { slot: "training_frame", resource_id: "0" }

      expect(flash[:alert]).to eq("We couldn't find that resource.")
    end
  end

  describe "GET the old certificate settings path" do
    it "redirects to resource roles" do
      sign_in admin

      get "/admin/certificate_settings"

      expect(response).to redirect_to(admin_resource_roles_path)
    end
  end

  describe "authorization" do
    it "denies a non-admin the page" do
      sign_in create(:user)

      get admin_resource_roles_path

      expect(response).not_to have_http_status(:ok)
    end

    it "denies a non-admin the certificate preview" do
      sign_in create(:user)

      get admin_resource_role_preview_path("training_frame")

      expect(response).not_to have_http_status(:ok)
    end

    it "denies a non-admin a connect, changing nothing" do
      resource = create(:resource)
      sign_in create(:user)

      patch admin_resource_roles_path, params: { slot: "training_frame", resource_id: resource.id }

      expect(response).not_to have_http_status(:ok)
      expect(resource.reload.role).to be_nil
    end
  end
end
