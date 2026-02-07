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

    it "cannot destroy another user's bookmark" do
      expect {
        delete bookmark_path(other_bookmark)
      }.not_to change(Bookmark, :count)

      expect(response).to redirect_to(root_path)
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

    it "can access personal bookmarks index" do
      get personal_bookmarks_path
      expect(response).to have_http_status(:ok)
    end

    it "can access tally" do
      get tally_bookmarks_path
      expect(response).to have_http_status(:ok)
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
  end
end
