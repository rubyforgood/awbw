require "rails_helper"

RSpec.describe "/story_ideas", type: :request do
  include ActiveJob::TestHelper

  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:organization)      { create(:organization) }

  let(:regular_user) { create(:user) }
  let(:admin)        { create(:user, :admin) }

  let(:valid_attributes) do
    {
      title: "The Future of Festivals",
      body: "An exploration of how technology transforms community events.",
      publish_preferences: "I would like my full name published",
      permission_given: true,
      windows_type_id: windows_type.id,
      workshop_id: workshop.id,
      organization_id: organization.id,
      created_by_id: regular_user.id,
      updated_by_id: regular_user.id
    }
  end

  let(:invalid_attributes) do
    {
      title: nil,                   # title is required
      body: "",                     # body cannot be blank
      publish_preferences: nil,     # missing preference
      created_by_id: nil            # missing creator
    }
  end

  context "as admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "renders successfully" do
        get story_ideas_url
        expect(response).to be_successful
      end
    end

    describe "GET /show" do
      it "renders successfully" do
        get story_idea_url(create(:story_idea))
        expect(response).to be_successful
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_story_idea_url
        expect(response).to be_successful
      end
    end

    describe "GET /update" do
      it "updates own story_idea" do
        story_idea = create(:story_idea)
        patch story_idea_url(story_idea),
              params: { story_idea: { title: "Updated Title" } }
        expect(response).to redirect_to(story_ideas_url)
        expect(story_idea.reload.title).to eq("Updated Title")
      end
    end

    describe "DELETE /destroy" do
      it "can delete any story_idea" do
        story_idea = create(:story_idea, created_by: create(:user))
        expect { delete story_idea_url(story_idea) }.to change(StoryIdea, :count).by(-1)
      end
    end

    describe "POST /create" do
      it "creates StoryIdea without FYI notification" do
        story_idea_count_before = StoryIdea.count
        notification_count_before = Notification.count

        post story_ideas_url, params: { story_idea: valid_attributes }

        expect(StoryIdea.count).to eq(story_idea_count_before + 1)
        expect(Notification.count).to eq(notification_count_before + 1)

        story_idea = StoryIdea.order(:id).last
        expect(story_idea).to be_present
      end
    end
  end

  context "as regular user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "redirects to root" do
        get story_ideas_url
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /show" do
      it "redirects to root" do
        story_idea = create(:story_idea)
        get story_idea_url(story_idea)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "creates a StoryIdea" do
        expect {
          post story_ideas_url, params: { story_idea: valid_attributes }
        }.to change(StoryIdea, :count).by(1)
      end

      it "creates a StoryIdea with external_workshop_title when workshop_id is 'new'" do
        attrs = valid_attributes.merge(
          workshop_id: "new",
          external_workshop_title: "My Custom Workshop"
        )

        post story_ideas_url, params: { story_idea: attrs }

        story_idea = StoryIdea.last
        expect(story_idea.workshop_id).to be_nil
        expect(story_idea.external_workshop_title).to eq("My Custom Workshop")
      end

      it "redirects to root after create" do
        post story_ideas_url, params: { story_idea: valid_attributes }
        expect(response).to redirect_to(root_path)
      end

      it "assigns current_user as owner" do
        post story_ideas_url, params: { story_idea: valid_attributes }
        expect(StoryIdea.last.created_by).to eq(regular_user)
      end

      it "creates an FYI notification and enqueues mailer job" do
        clear_enqueued_jobs

        expect {
          post story_ideas_url, params: { story_idea: valid_attributes }
        }.to change(StoryIdea, :count).by(1)
                                      .and change(Notification, :count).by(1)

        notification = Notification.last
        story_idea   = StoryIdea.last

        expect(notification.kind).to eq("idea_submitted_fyi")
        expect(notification.noticeable).to eq(story_idea)
        expect(notification.recipient_role).to eq("admin")

        expect(enqueued_jobs.map { |j| j[:job] })
          .to include(NotificationMailerJob)
      end
    end

    describe "POST /create with invalid params" do
      it "does not create StoryIdea" do
        expect {
          post story_ideas_url, params: { story_idea: invalid_attributes }
        }.not_to change(StoryIdea, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post story_ideas_url, params: { story_idea: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "PATCH /update" do
      let(:story_idea) { create(:story_idea, created_by: regular_user) }

      it "cannot update even own story_idea" do
        original_title = story_idea.title
        patch story_idea_url(story_idea),
              params: { story_idea: { title: "Updated Title" } }
        expect(response).to redirect_to(root_path)
        expect(story_idea.reload.title).to eq(original_title)
      end

      it "redirects to root" do
        story_idea = StoryIdea.create! valid_attributes
        patch story_idea_url(story_idea), params: { story_idea: valid_attributes }
        story_idea.reload
        expect(response).to redirect_to(root_path)
      end

      it "cannot update someone else's story_idea" do
        other_story_idea = create(:story_idea, created_by: create(:user))

        patch story_idea_url(other_story_idea),
              params: { story_idea: { title: "Hack Attempt" } }

        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /destroy" do
      it "cannot delete own story_idea" do
        story_idea = create(:story_idea, created_by: regular_user)

        expect {
          delete story_idea_url(story_idea)
        }.not_to change(StoryIdea, :count)
      end

      it "cannot delete someone else's story_idea" do
        story_idea = create(:story_idea, created_by: create(:user))

        delete story_idea_url(story_idea)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  context "as regular user who is an owner of a story_idea" do
    before { sign_in regular_user }

    describe "GET /show" do
      it "renders successfully if owner" do
        story_idea = create(:story_idea, created_by: regular_user)
        get story_idea_url(story_idea)
        expect(response).to be_successful
      end
    end
  end

  context "as guest" do
    describe "GET /index" do
      it "redirects to root" do
        get story_ideas_url
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /show" do
      it "redirects to root" do
        story_idea = create(:story_idea)
        get story_idea_url(story_idea)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /new" do
      it "redirects to root" do
        get new_story_idea_url
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "does not create a StoryIdea and redirects to root" do
        expect {
          post story_ideas_url, params: { story_idea: valid_attributes }
        }.not_to change(StoryIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /update" do
      it "does not update StoryIdea and redirects to root" do
        story_idea = create(:story_idea, title: "Original Title")

        patch story_idea_url(story_idea),
              params: { story_idea: { title: "Updated Title" } }

        expect(response).to redirect_to(root_path)
        expect(story_idea.reload.title).to eq("Original Title")
      end
    end

    describe "DELETE /destroy" do
      it "does not delete StoryIdea and redirects to root" do
        story_idea = create(:story_idea)

        expect {
          delete story_idea_url(story_idea)
        }.not_to change(StoryIdea, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
