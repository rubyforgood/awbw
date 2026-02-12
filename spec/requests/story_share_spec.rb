require "rails_helper"

RSpec.describe "/story_share", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:organization) { create(:organization) }

  let(:base_attributes) do
    {
      title: "Story #{SecureRandom.hex(4)}",
      body: "Once upon a time...",
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
      it "returns success" do
        get story_share_index_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "can view any story" do
        get story_share_path(private_story)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ==========================================================
  # REGULAR USER (authenticated, not admin)
  # ==========================================================
  describe "as regular_user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "returns success" do
        get story_share_index_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "can view published story" do
        get story_share_path(published_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view private story" do
        get story_share_path(private_story)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ==========================================================
  # GUEST (not authenticated)
  # ==========================================================
  describe "as guest" do
    describe "GET /index" do
      it "returns success" do
        get story_share_index_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "can view publicly visible story" do
        get story_share_path(public_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view published-only story" do
        get story_share_path(published_story)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
