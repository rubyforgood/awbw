require "rails_helper"

RSpec.describe "/featured_stories", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:first_story)  { create(:story, :featured, :published, title: "First featured") }
  let!(:second_story) { create(:story, :featured, :published, title: "Second featured") }

  describe "GET /index" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the reorder page with featured stories" do
        get featured_stories_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("First featured")
        expect(response.body).to include("Second featured")
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "redirects away from the reorder page" do
        get featured_stories_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get featured_stories_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PUT /update" do
    context "as an admin" do
      before { sign_in admin }

      it "moves the story to the requested position" do
        put featured_story_path(second_story), params: { position: 1 }, as: :json

        expect(response).to have_http_status(:no_content)
        expect(second_story.reload.position).to eq(1)
        expect(first_story.reload.position).to eq(2)
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "is not authorized and leaves the order unchanged" do
        put featured_story_path(second_story), params: { position: 1 }, as: :json

        expect(response).to redirect_to(root_path)
        expect(second_story.reload.position).to eq(2)
      end
    end
  end
end
