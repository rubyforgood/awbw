# spec/requests/bookmarks_spec.rb
require "rails_helper"

RSpec.describe "Bookmarks", type: :request do
	let(:user) { create(:user) }
	let!(:bookmark) { create(:bookmark, user: user) }
  let(:workshop) { create(:workshop) }

	before do
		sign_in user
	end

  describe "POST /bookmarks" do
    it "creates a bookmark and responds with turbo_stream" do
      expect {
        post bookmarks_path,
          params: {bookmark: {bookmarkable_id: workshop.id, bookmarkable_type: "Workshop"}},
          headers: {"Accept" => "text/vnd.turbo-stream.html"}
      }.to change(Bookmark, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Workshop added to your bookmarks.")
    end
  end

  describe "DELETE /bookmarks/:id" do
    it "destroys a bookmark and responds with turbo_stream" do
      expect {
        delete bookmark_path(bookmark),
          headers: {"Accept" => "text/vnd.turbo-stream.html"}
      }.to change(Bookmark, :count).by(-1)

      expect(Bookmark.exists?(bookmark.id)).to be_falsey
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Bookmark has been deleted.")
    end
  end
end
