require "rails_helper"

RSpec.describe "/workshop_ideas", type: :request do
  let(:regular_user) { create(:user) }
  let(:admin)        { create(:user, super_user: true) }
  let(:windows_type) { create(:windows_type) }

  let(:valid_attributes) do
    {
      title: "Mindful Art Session",
      description: "An activity to promote self-expression and focus.",
      objective: "Encourage creativity and emotional awareness.",
      materials: "Paper, markers, glue",
      tips: "Play calming music during creation.",
      created_by_id: regular_user.id,
      updated_by_id: regular_user.id,
      windows_type_id: windows_type.id,
      age_range: "10–14",
      time_creation: 30
    }
  end

  let(:invalid_attributes) do
    {
      title: "",
      created_by_id: nil,
      windows_type_id: nil
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
        create(:workshop_idea, valid_attributes)
        get workshop_ideas_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "renders successfully" do
        idea = create(:workshop_idea, valid_attributes)
        get workshop_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_workshop_idea_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /edit" do
      it "renders successfully" do
        idea = create(:workshop_idea, valid_attributes)
        get edit_workshop_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /create" do
      it "creates a WorkshopIdea" do
        expect {
          post workshop_ideas_path, params: { workshop_idea: valid_attributes }
        }.to change(WorkshopIdea, :count).by(1)

        expect(response).to redirect_to(workshop_ideas_path)
      end
    end

    describe "PATCH /update" do
      it "updates the workshop idea" do
        idea = create(:workshop_idea, valid_attributes)

        patch workshop_idea_path(idea),
              params: { workshop_idea: { title: "Updated Title" } }

        expect(idea.reload.title).to eq("Updated Title")
        expect(response).to redirect_to(workshop_ideas_path)
      end
    end

    describe "DELETE /destroy" do
      it "destroys the workshop idea" do
        idea = create(:workshop_idea, valid_attributes)

        expect {
          delete workshop_idea_path(idea)
        }.to change(WorkshopIdea, :count).by(-1)

        expect(response).to redirect_to(workshop_ideas_path)
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
        get workshop_ideas_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /show" do
      it "renders owned workshop_idea successfully" do
        idea = create(:workshop_idea, valid_attributes) # owner == regular_user
        get workshop_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end

      it "redirects from another's workshop_idea to root" do
        idea = create(:workshop_idea, valid_attributes.merge(created_by_id: admin.id)) # NOT an owner
        get workshop_idea_path(idea)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      context "with valid params" do
        it "creates a WorkshopIdea" do
          expect {
            post workshop_ideas_path,
                 params: { workshop_idea: valid_attributes }
          }.to change(WorkshopIdea, :count).by(1)
        end
      end

      context "with invalid params" do
        it "does not create and returns 422" do
          expect {
            post workshop_ideas_path,
                 params: { workshop_idea: invalid_attributes }
          }.not_to change(WorkshopIdea, :count)

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "PATCH /update" do
      let(:idea) { create(:workshop_idea, valid_attributes) }

      it "does not update with valid params" do
        original_title = idea.title
        patch workshop_idea_path(idea),
              params: { workshop_idea: { title: "Updated Title" } }
        expect(idea.reload.title).to eq(original_title)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /destroy" do
      it "does not destroy the idea" do
        idea = create(:workshop_idea, valid_attributes)

        expect {
          delete workshop_idea_path(idea)
        }.not_to change(WorkshopIdea, :count)
      end
    end
  end

  # ============================================================
  # GUEST
  # ============================================================

  context "as a guest" do
    describe "GET /index" do
      it "redirects to root" do
        get workshop_ideas_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "does not create and redirects to root" do
        expect {
          post workshop_ideas_path,
               params: { workshop_idea: valid_attributes }
        }.not_to change(WorkshopIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /update" do
      it "redirects to root" do
        idea = create(:workshop_idea, valid_attributes)

        patch workshop_idea_path(idea),
              params: { workshop_idea: { title: "Updated" } }

        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /destroy" do
      it "does not delete and redirects to root" do
        idea = create(:workshop_idea, valid_attributes)

        expect {
          delete workshop_idea_path(idea)
        }.not_to change(WorkshopIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
