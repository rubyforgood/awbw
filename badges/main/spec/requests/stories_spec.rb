require "rails_helper"

RSpec.describe "/stories", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:organization) { create(:organization) }

  let(:base_attributes) do
    {
      title: "Story #{SecureRandom.hex(4)}",
      rhino_body: "<p>Once upon a time...</p>",
      windows_type_id: windows_type.id,
      workshop_id: workshop.id,
      organization_id: organization.id,
      created_by_id: admin.id,
      updated_by_id: admin.id
    }
  end

  let!(:published_story) do
    Story.create!(base_attributes.merge(
      title: "Story #{SecureRandom.hex(4)}",
      published: true
    ))
  end

  let!(:public_story) do
    create(:story, :published, :publicly_visible)
  end

  let!(:private_story) do
    Story.create!(base_attributes.merge(
      title: "Story #{SecureRandom.hex(4)}",
      published: false,
      publicly_visible: false
    ))
  end

  # ==========================================================
  # ADMIN
  # ==========================================================
  describe "as admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "returns all stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "story_results" }
        expect(response.body).to include(published_story.title)
        expect(response.body).to include(public_story.title)
        expect(response.body).to include(private_story.title)
      end
    end

    describe "GET /show" do
      it "can view any story" do
        get story_url(private_story)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /create" do
      it "creates a story" do
        expect {
          post stories_url, params: { story: base_attributes }
        }.to change(Story, :count).by(1)

        expect(response).to redirect_to(stories_path)
      end
    end
  end

  # ==========================================================
  # REGULAR USER (authenticated, not admin)
  # ==========================================================
  describe "as regular_user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "only shows published stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "story_results" }

        expect(response.body).to include(published_story.title)
        expect(response.body).to include(public_story.title)
        expect(response.body).not_to include(private_story.title)
      end
    end

    describe "GET /show" do
      it "can view published story" do
        get story_url(published_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view private story" do
        get story_url(private_story)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "is unauthorized" do
        post stories_url, params: { story: base_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ==========================================================
  # GUEST (not authenticated)
  # ==========================================================
  describe "as guest" do
    describe "GET /index" do
      it "only shows publicly_visible stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "story_results" }

        expect(response.body).to include(public_story.title)
        expect(response.body).not_to include(published_story.title)
        expect(response.body).not_to include(private_story.title)
      end
    end

    describe "GET /show" do
      it "can view publicly visible story" do
        get story_url(public_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view published-only story" do
        get story_url(published_story)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "redirects to root" do
        post stories_url, params: { story: base_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
