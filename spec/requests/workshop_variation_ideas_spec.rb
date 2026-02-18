require "rails_helper"

RSpec.describe "/workshop_variation_ideas", type: :request do
  let(:regular_user) { create(:user) }
  let(:admin)        { create(:user, super_user: true) }
  let(:workshop)     { create(:workshop) }
  let(:organization) { create(:organization) }
  let(:windows_type) { create(:windows_type) }

  let(:valid_attributes) do
    {
      name: "Mindful Art Variation",
      rhino_body: "<p>A variation focusing on mindfulness and relaxation.</p>",
      youtube_url: "https://www.youtube.com/watch?v=example",
      permission_given: true,
      publish_preferences: "public",
      workshop_id: workshop.id,
      organization_id: organization.id,
      windows_type_id: windows_type.id,
      created_by_id: regular_user.id,
      updated_by_id: regular_user.id
    }
  end

  let(:invalid_attributes) do
    {
      name: "",
      workshop_id: nil,
      created_by_id: nil
    }
  end

  before do
    allow(NotificationServices::CreateNotification).to receive(:call)
  end

  # ============================================================
  # ADMIN
  # ============================================================

  context "as an admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "renders successfully" do
        create(:workshop_variation_idea, valid_attributes)
        get workshop_variation_ideas_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "renders successfully" do
        idea = create(:workshop_variation_idea, valid_attributes)
        get workshop_variation_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_workshop_variation_idea_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /edit" do
      it "renders successfully" do
        idea = create(:workshop_variation_idea, valid_attributes)
        get edit_workshop_variation_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /create" do
      context "with valid params" do
        it "creates a WorkshopVariationIdea" do
          expect {
            post workshop_variation_ideas_path, params: { workshop_variation_idea: valid_attributes }
          }.to change(WorkshopVariationIdea, :count).by(1)

          expect(response).to redirect_to(workshop_variation_ideas_path)
        end

        it "sends a notification" do
          expect(NotificationServices::CreateNotification).to receive(:call).with(
            hash_including(
              kind: :idea_submitted_fyi,
              recipient_role: :admin
            )
          )

          post workshop_variation_ideas_path, params: { workshop_variation_idea: valid_attributes }
        end
      end

      context "with invalid params" do
        it "does not create and returns 422" do
          expect {
            post workshop_variation_ideas_path, params: { workshop_variation_idea: invalid_attributes }
          }.not_to change(WorkshopVariationIdea, :count)

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "PATCH /update" do
      it "updates the workshop variation idea" do
        idea = create(:workshop_variation_idea, valid_attributes)

        patch workshop_variation_idea_path(idea),
              params: { workshop_variation_idea: { name: "Updated Name" } }

        expect(idea.reload.name).to eq("Updated Name")
        expect(response).to redirect_to(workshop_variation_ideas_path)
      end
    end

    describe "DELETE /destroy" do
      it "destroys the workshop variation idea" do
        idea = create(:workshop_variation_idea, valid_attributes)

        expect {
          delete workshop_variation_idea_path(idea)
        }.to change(WorkshopVariationIdea, :count).by(-1)

        expect(response).to redirect_to(workshop_variation_ideas_path)
      end
    end
  end

  # ============================================================
  # REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "redirects to root" do
        get workshop_variation_ideas_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /show" do
      it "renders owned workshop_variation_idea successfully" do
        idea = create(:workshop_variation_idea, valid_attributes) # owner == regular_user
        get workshop_variation_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end

      it "redirects from another's workshop_variation_idea to root" do
        idea = create(:workshop_variation_idea, valid_attributes.merge(created_by_id: admin.id))
        get workshop_variation_idea_path(idea)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_workshop_variation_idea_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /create" do
      context "with valid params" do
        it "creates a WorkshopVariationIdea" do
          expect {
            post workshop_variation_ideas_path,
                 params: { workshop_variation_idea: valid_attributes }
          }.to change(WorkshopVariationIdea, :count).by(1)

          expect(response).to redirect_to(root_path)
        end
      end

      context "with invalid params" do
        it "does not create and returns 422" do
          expect {
            post workshop_variation_ideas_path,
                 params: { workshop_variation_idea: invalid_attributes }
          }.not_to change(WorkshopVariationIdea, :count)

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "PATCH /update" do
      it "does not update with valid params" do
        idea = create(:workshop_variation_idea, valid_attributes)
        original_name = idea.name

        patch workshop_variation_idea_path(idea),
              params: { workshop_variation_idea: { name: "Updated Name" } }

        expect(idea.reload.name).to eq(original_name)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /destroy" do
      it "does not destroy the idea" do
        idea = create(:workshop_variation_idea, valid_attributes)

        expect {
          delete workshop_variation_idea_path(idea)
        }.not_to change(WorkshopVariationIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ============================================================
  # GUEST
  # ============================================================

  context "as a guest" do
    describe "GET /index" do
      it "redirects to root" do
        get workshop_variation_ideas_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /new" do
      it "redirects to root" do
        get new_workshop_variation_idea_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "does not create and redirects to root" do
        expect {
          post workshop_variation_ideas_path,
               params: { workshop_variation_idea: valid_attributes }
        }.not_to change(WorkshopVariationIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /update" do
      it "redirects to root" do
        idea = create(:workshop_variation_idea, valid_attributes)

        patch workshop_variation_idea_path(idea),
              params: { workshop_variation_idea: { name: "Updated" } }

        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /destroy" do
      it "does not delete and redirects to root" do
        idea = create(:workshop_variation_idea, valid_attributes)

        expect {
          delete workshop_variation_idea_path(idea)
        }.not_to change(WorkshopVariationIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
