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

      describe "sorting" do
        let(:turbo_headers) { { "Turbo-Frame" => "story_results" } }

        let(:org_alpha) { create(:organization, name: "Alpha Org") }
        let(:org_zulu) { create(:organization, name: "Zulu Org") }
        let(:wt_adult) { create(:windows_type, short_name: "ADULT") }
        let(:wt_children) { create(:windows_type, short_name: "CHILDREN") }
        let(:ws_art) { create(:workshop, title: "Art Workshop") }
        let(:ws_music) { create(:workshop, title: "Music Workshop") }

        let(:author_alice) do
          person = create(:person, first_name: "Alice", last_name: "Smith")
          person.user
        end
        let(:author_zara) do
          person = create(:person, first_name: "Zara", last_name: "Jones")
          person.user
        end

        let!(:story_a) do
          create(:story, :published,
            title: "Alpha Story",
            windows_type: wt_adult,
            workshop: ws_art,
            organization: org_alpha,
            created_by: author_alice).tap do |s|
            s.update_columns(created_at: 3.days.ago, updated_at: 1.day.ago)
          end
        end

        let!(:story_z) do
          create(:story, :published,
            title: "Zulu Story",
            windows_type: wt_children,
            workshop: ws_music,
            organization: org_zulu,
            created_by: author_zara).tap do |s|
            s.update_columns(created_at: 1.day.ago, updated_at: 3.days.ago)
          end
        end

        def titles_in_response
          response.body.scan(/(?:Alpha|Zulu) Story/)
        end

        it "defaults to created_at desc when no sort param" do
          get stories_url, params: {}, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by title asc" do
          get stories_url, params: { sort: "title", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by title desc" do
          get stories_url, params: { sort: "title", direction: "desc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by updated_at asc" do
          get stories_url, params: { sort: "updated_at", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by windows_type asc" do
          get stories_url, params: { sort: "windows_type", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by workshop asc" do
          get stories_url, params: { sort: "workshop", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by author asc" do
          get stories_url, params: { sort: "author", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by organization asc" do
          get stories_url, params: { sort: "organization", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "falls back to created_at desc for invalid sort column" do
          get stories_url, params: { sort: "bogus" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "combines sort with title filter" do
          get stories_url, params: { sort: "title", direction: "desc", title: "Story" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end
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

        expect(response).to redirect_to(story_url(Story.last))
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
