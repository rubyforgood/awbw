require 'rails_helper'

RSpec.describe "/workshop_ideas", type: :request do
    let(:user) { create(:user) }
  let(:windows_type) { create(:windows_type) }

  let(:valid_attributes) do
    {
      title: "Mindful Art Session",
      description: "An activity to promote self-expression and focus.",
      objective: "Encourage creativity and emotional awareness.",
      materials: "Paper, markers, glue",
      tips: "Play calming music during creation.",
      created_by_id: user.id,
      updated_by_id: user.id,
      windows_type_id: windows_type.id,
      age_range: "10–14",
      time_creation: 30
    }
  end

  let(:invalid_attributes) do
    {
      title: "", # invalid because title is required
      created_by_id: nil,
      windows_type_id: nil
    }
  end

  before { sign_in user } # Devise helper for authenticated routes

  describe "GET /index" do
    it "renders a successful response" do
      create(:workshop_idea, valid_attributes)
      get workshop_ideas_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      workshop_idea = create(:workshop_idea, valid_attributes)
      get workshop_idea_url(workshop_idea)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_workshop_idea_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      workshop_idea = create(:workshop_idea, valid_attributes)
      get edit_workshop_idea_url(workshop_idea)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new WorkshopIdea" do
        expect {
          post workshop_ideas_url, params: { workshop_idea: valid_attributes }
        }.to change(WorkshopIdea, :count).by(1)
      end

      it "redirects to the created workshop_idea" do
        post workshop_ideas_url, params: { workshop_idea: valid_attributes }
        expect(response).to redirect_to(workshop_ideas_url)
      end
    end

    context "with invalid parameters" do
      it "does not create a new WorkshopIdea" do
        expect {
          post workshop_ideas_url, params: { workshop_idea: invalid_attributes }
        }.not_to change(WorkshopIdea, :count)
      end

      it "renders a response with 422 status" do
        post workshop_ideas_url, params: { workshop_idea: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    let(:workshop_idea) { create(:workshop_idea, valid_attributes) }
    let(:new_attributes) { { title: "Updated Workshop Title" } }

    context "with valid parameters" do
      it "updates the requested workshop_idea" do
        patch workshop_idea_url(workshop_idea), params: { workshop_idea: new_attributes }
        workshop_idea.reload
        expect(workshop_idea.title).to eq("Updated Workshop Title")
      end

      it "redirects to the workshop_idea" do
        patch workshop_idea_url(workshop_idea), params: { workshop_idea: new_attributes }
        expect(response).to redirect_to(workshop_ideas_url)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        patch workshop_idea_url(workshop_idea), params: { workshop_idea: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested workshop_idea" do
      workshop_idea = create(:workshop_idea, valid_attributes)
      expect {
        delete workshop_idea_url(workshop_idea)
      }.to change(WorkshopIdea, :count).by(-1)
    end

    it "redirects to the workshop_ideas list" do
      workshop_idea = create(:workshop_idea, valid_attributes)
      delete workshop_idea_url(workshop_idea)
      expect(response).to redirect_to(workshop_ideas_url)
    end
  end
end
