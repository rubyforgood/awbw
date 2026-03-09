require "rails_helper"

RSpec.describe "Bookmarks", type: :request do
  let(:regular_user) { create(:user) }
  let(:admin)        { create(:user, super_user: true) }
  let(:other_user)   { create(:user) }
  let(:workshop)     { create(:workshop) }
  let(:new_workshop) { create(:workshop) }

  let!(:bookmark)       { create(:bookmark, user: regular_user, bookmarkable: workshop) }
  let!(:other_bookmark) { create(:bookmark, user: other_user, bookmarkable: workshop) }

  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  # ============================================================
  # GUEST
  # ============================================================

  context "as a guest" do
    it "cannot access index" do
      get bookmarks_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot access personal bookmarks index" do
      get personal_bookmarks_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot access tally" do
      get tally_bookmarks_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot create bookmark and redirects to root" do
      expect {
        post bookmarks_path,
             params: { bookmark: { bookmarkable_id: workshop.id, bookmarkable_type: "Workshop" } }
      }.not_to change(Bookmark, :count)

      expect(response).to redirect_to(root_path)
    end

    it "cannot destroy bookmark and redirects to root" do
      expect {
        delete bookmark_path(bookmark)
      }.not_to change(Bookmark, :count)

      expect(response).to redirect_to(root_path)
    end

    context "with video_recordings" do
      let(:video_recording) { create(:video_recording, :published) }

      it "cannot create a video_recording bookmark" do
        expect {
          post bookmarks_path,
               params: { bookmark: { bookmarkable_id: video_recording.id,
                                     bookmarkable_type: "VideoRecording" } }
        }.not_to change(Bookmark, :count)

        expect(response).to redirect_to(root_path)
      end

      it "cannot destroy a video_recording bookmark" do
        video_recording_bookmark = create(:bookmark, user: regular_user, bookmarkable: video_recording)
        expect {
          delete bookmark_path(video_recording_bookmark)
        }.not_to change(Bookmark, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ============================================================
  # REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in regular_user }

    it "cannot access global index" do
      get bookmarks_path
      expect(response).to redirect_to(root_path)
    end

    it "can access personal bookmarks" do
      get personal_bookmarks_path
      expect(response).to have_http_status(:ok)
    end

    it "includes WorkshopVariationIdea in bookmark type dropdown" do
      get personal_bookmarks_path
      expect(response.body).to include("value=\"WorkshopVariationIdea\"")
    end

    it "does not include Report in bookmark type dropdown" do
      get personal_bookmarks_path
      expect(response.body).not_to include("value=\"Report\"")
    end

    it "includes Video in bookmark type dropdown" do
      get personal_bookmarks_path
      expect(response.body).to include(VideoRecording.model_name.human)
    end

    it "can access personal bookmarks sorted by title via turbo frame" do
      get personal_bookmarks_path, params: { sort: "title" },
          headers: { "Turbo-Frame" => "personal_bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can access personal bookmarks with keyword filter and title sort via turbo frame" do
      get personal_bookmarks_path, params: { sort: "title", keyword: "test" },
          headers: { "Turbo-Frame" => "personal_bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "renders shell page without results for non-turbo personal request" do
      get personal_bookmarks_path
      expect(response.body).to include("personal_bookmarks_results")
      expect(response.body).to include("Keyword")
    end

    it "renders results for turbo frame personal request" do
      get personal_bookmarks_path,
          headers: { "Turbo-Frame" => "personal_bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can filter personal bookmarks by keyword via turbo frame" do
      get personal_bookmarks_path, params: { keyword: workshop.title },
          headers: { "Turbo-Frame" => "personal_bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can sort personal bookmarks by popularity via turbo frame" do
      get personal_bookmarks_path, params: { sort: "popularity", direction: "desc" },
          headers: { "Turbo-Frame" => "personal_bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "cannot access tally index" do
      get tally_bookmarks_path
      expect(response).to redirect_to(root_path)
    end

    it "can create bookmark" do
      expect {
        post bookmarks_path,
             params: { bookmark: { bookmarkable_id: new_workshop.id,
                                   bookmarkable_type: "Workshop" } },
             headers: turbo_headers
      }.to change(Bookmark, :count).by(1)
    end

    it "can destroy their own bookmark" do
      expect {
        delete bookmark_path(bookmark), headers: turbo_headers
      }.to change(Bookmark, :count).by(-1)
    end

    it "renders unbookmarked state in turbo_stream after destroy" do
      delete bookmark_path(bookmark), headers: turbo_headers

      expect(response.body).to include("far fa-bookmark")
      expect(response.body).not_to include("fas fa-bookmark")
    end

    it "cannot destroy another user's bookmark" do
      expect {
        delete bookmark_path(other_bookmark)
      }.not_to change(Bookmark, :count)

      expect(response).to redirect_to(root_path)
    end

    context "with video_recordings" do
      let(:video_recording) { create(:video_recording, :published) }

      it "can create a video_recording bookmark" do
        expect {
          post bookmarks_path,
               params: { bookmark: { bookmarkable_id: video_recording.id,
                                     bookmarkable_type: "VideoRecording" } },
               headers: turbo_headers
        }.to change(Bookmark, :count).by(1)
      end

      it "can destroy their own video_recording bookmark" do
        video_recording_bookmark = create(:bookmark, user: regular_user, bookmarkable: video_recording)
        expect {
          delete bookmark_path(video_recording_bookmark), headers: turbo_headers
        }.to change(Bookmark, :count).by(-1)
      end
    end
  end

  # ============================================================
  # ADMIN
  # ============================================================

  context "as an admin" do
    before { sign_in admin }

    it "can access global index" do
      get bookmarks_path
      expect(response).to have_http_status(:ok)
    end

    it "can access global index sorted by title via turbo frame" do
      get bookmarks_path, params: { sort: "title" },
          headers: { "Turbo-Frame" => "bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can access global index with keyword filter and title sort via turbo frame" do
      get bookmarks_path, params: { sort: "title", keyword: "test" },
          headers: { "Turbo-Frame" => "bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "renders shell page for non-turbo index request" do
      get bookmarks_path
      expect(response.body).to include("bookmarks_results")
      expect(response.body).to include("Keyword")
    end

    it "renders results for turbo frame index request" do
      get bookmarks_path,
          headers: { "Turbo-Frame" => "bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can filter index by keyword via turbo frame" do
      get bookmarks_path, params: { keyword: workshop.title },
          headers: { "Turbo-Frame" => "bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can sort index by popularity via turbo frame" do
      get bookmarks_path, params: { sort: "popularity", direction: "asc" },
          headers: { "Turbo-Frame" => "bookmarks_results" }
      expect(response).to have_http_status(:ok)
    end

    it "can access personal bookmarks index" do
      get personal_bookmarks_path
      expect(response).to have_http_status(:ok)
    end

    it "can access tally" do
      get tally_bookmarks_path
      expect(response).to have_http_status(:ok)
    end

    it "includes WorkshopVariationIdea in bookmark type dropdown" do
      get bookmarks_path
      expect(response.body).to include("value=\"WorkshopVariationIdea\"")
    end

    it "does not include Report in bookmark type dropdown" do
      get bookmarks_path
      expect(response.body).not_to include("value=\"Report\"")
    end

    it "can create bookmark" do
      expect {
        post bookmarks_path,
             params: { bookmark: { bookmarkable_id: workshop.id, bookmarkable_type: "Workshop" } },
             headers: turbo_headers
      }.to change(Bookmark, :count).by(1)
    end

    it "can destroy any bookmark" do
      expect {
        delete bookmark_path(other_bookmark)
      }.to change(Bookmark, :count).by(-1)
    end

    context "with video_recordings" do
      let(:video_recording) { create(:video_recording, :published) }

      it "can create a video_recording bookmark" do
        expect {
          post bookmarks_path,
               params: { bookmark: { bookmarkable_id: video_recording.id,
                                     bookmarkable_type: "VideoRecording" } },
               headers: turbo_headers
        }.to change(Bookmark, :count).by(1)
      end

      it "can destroy any video_recording bookmark" do
        video_recording_bookmark = create(:bookmark, user: other_user, bookmarkable: video_recording)
        expect {
          delete bookmark_path(video_recording_bookmark)
        }.to change(Bookmark, :count).by(-1)
      end
    end
  end
end
