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
      author_credit_preference: "full_name",
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

      it "displays the organization name when present" do
        org = create(:organization, name: "Sunset Arts")
        create(:workshop_idea, valid_attributes.merge(organization: org))
        get workshop_ideas_path
        expect(response.body).to include("Sunset Arts")
      end

      it "does not error when organization is nil" do
        create(:workshop_idea, valid_attributes.merge(organization: nil))
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

      it "displays the organization name when present" do
        org = create(:organization, name: "Sunset Arts")
        idea = create(:workshop_idea, valid_attributes.merge(organization: org))
        get workshop_idea_path(idea)
        expect(response.body).to include("Sunset Arts")
      end

      it "does not error when organization is nil" do
        idea = create(:workshop_idea, valid_attributes.merge(organization: nil))
        get workshop_idea_path(idea)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_workshop_idea_path
        expect(response).to have_http_status(:ok)
      end

      it "offers every organization in the dropdown, including ones the admin isn't affiliated with" do
        first_org = create(:organization, name: "First Arts Org")
        second_org = create(:organization, name: "Second Arts Org")

        get new_workshop_idea_path

        page = Capybara.string(response.body)
        option_values = page.all("select[name='workshop_idea[organization_id]'] option").map(&:value)
        expect(option_values).to include(first_org.id.to_s, second_org.id.to_s)
        expect(option_values).to include("")
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

        expect(response).to redirect_to(workshop_idea_path(WorkshopIdea.last))
      end

      it "creates a WorkshopIdea with an organization" do
        org = create(:organization)
        expect {
          post workshop_ideas_path, params: { workshop_idea: valid_attributes.merge(organization_id: org.id) }
        }.to change(WorkshopIdea, :count).by(1)

        expect(WorkshopIdea.last.organization).to eq(org)
      end

      it "creates a WorkshopIdea without an organization" do
        expect {
          post workshop_ideas_path, params: { workshop_idea: valid_attributes.merge(organization_id: "") }
        }.to change(WorkshopIdea, :count).by(1)

        expect(WorkshopIdea.last.organization).to be_nil
      end

      it "sends admin and submitter notifications" do
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          hash_including(
            kind: :idea_submitted,
            recipient_role: :person
          )
        )
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          hash_including(
            kind: :idea_submitted_fyi,
            recipient_role: :admin
          )
        )

        post workshop_ideas_path, params: { workshop_idea: valid_attributes }
      end

      it "handles RecordNotUnique gracefully" do
        allow_any_instance_of(WorkshopIdea).to receive(:save).and_raise(
          ActiveRecord::RecordNotUnique.new("Duplicate entry")
        )

        expect {
          post workshop_ideas_path, params: { workshop_idea: valid_attributes }
        }.not_to change(WorkshopIdea, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "PATCH /update" do
      it "updates the workshop idea" do
        idea = create(:workshop_idea, valid_attributes)

        patch workshop_idea_path(idea),
              params: { workshop_idea: { title: "Updated Title" } }

        expect(idea.reload.title).to eq("Updated Title")
        expect(response).to redirect_to(workshop_idea_path(idea))
      end

      it "updates the organization_id" do
        idea = create(:workshop_idea, valid_attributes)
        org = create(:organization)

        patch workshop_idea_path(idea),
              params: { workshop_idea: { organization_id: org.id } }

        expect(idea.reload.organization_id).to eq(org.id)
      end

      it "allows clearing the organization_id" do
        org = create(:organization)
        idea = create(:workshop_idea, valid_attributes.merge(organization: org))

        patch workshop_idea_path(idea),
              params: { workshop_idea: { organization_id: "" } }

        expect(idea.reload.organization_id).to be_nil
      end

      it "handles RecordNotUnique gracefully" do
        idea = create(:workshop_idea, valid_attributes)

        allow_any_instance_of(WorkshopIdea).to receive(:update).and_raise(
          ActiveRecord::RecordNotUnique.new("Duplicate entry")
        )

        patch workshop_idea_path(idea),
              params: { workshop_idea: { title: "Updated Title" } }

        expect(response).to have_http_status(:unprocessable_content)
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

    describe "GET /new" do
      before do
        allow_any_instance_of(WorkshopIdeaPolicy).to receive(:new?).and_return(true)
      end

      it "fills in the one organization the user is currently active at" do
        person = create(:person, user: regular_user)
        current_org = create(:organization, name: "Current Arts Org")
        past_org = create(:organization, name: "Former Arts Org")
        create(:affiliation, person: person, organization: current_org, start_date: 1.year.ago)
        create(:affiliation, person: person, organization: current_org, start_date: 5.years.ago, end_date: 3.years.ago)
        create(:affiliation, person: person, organization: past_org, start_date: 3.years.ago, end_date: 2.years.ago)

        get new_workshop_idea_path

        page = Capybara.string(response.body)
        expect(page).to have_field("workshop_idea[organization_id]", type: :hidden, with: current_org.id.to_s)
        expect(page).not_to have_select("workshop_idea[organization_id]")
        expect(page).not_to have_text(past_org.name)
      end

      it "lets the user choose among several current organizations" do
        person = create(:person, user: regular_user)
        first_org = create(:organization, name: "First Arts Org")
        second_org = create(:organization, name: "Second Arts Org")
        past_org = create(:organization, name: "Former Arts Org")
        create(:affiliation, person: person, organization: first_org)
        create(:affiliation, person: person, organization: second_org)
        create(:affiliation, person: person, organization: past_org, inactive: true)

        get new_workshop_idea_path

        page = Capybara.string(response.body)
        option_values = page.all("select[name='workshop_idea[organization_id]'] option").map(&:value)
        expect(option_values).to eq([ "", first_org.id.to_s, second_org.id.to_s ])
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

        it "creates a WorkshopIdea with an organization" do
          org = create(:organization)
          expect {
            post workshop_ideas_path,
                 params: { workshop_idea: valid_attributes.merge(organization_id: org.id) }
          }.to change(WorkshopIdea, :count).by(1)

          expect(WorkshopIdea.last.organization).to eq(org)
        end

        it "creates a WorkshopIdea without an organization" do
          expect {
            post workshop_ideas_path,
                 params: { workshop_idea: valid_attributes.merge(organization_id: "") }
          }.to change(WorkshopIdea, :count).by(1)

          expect(WorkshopIdea.last.organization).to be_nil
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
      it "redirects to new user session path" do
        get workshop_ideas_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "POST /create" do
      it "does not create and redirects to new user session path" do
        expect {
          post workshop_ideas_path,
               params: { workshop_idea: valid_attributes }
        }.not_to change(WorkshopIdea, :count)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "PATCH /update" do
      it "redirects to new user session path" do
        idea = create(:workshop_idea, valid_attributes)

        patch workshop_idea_path(idea),
              params: { workshop_idea: { title: "Updated" } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "DELETE /destroy" do
      it "does not delete and redirects to new user session path" do
        idea = create(:workshop_idea, valid_attributes)

        expect {
          delete workshop_idea_path(idea)
        }.not_to change(WorkshopIdea, :count)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
