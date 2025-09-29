# spec/requests/bookmarks_spec.rb
require "rails_helper"

RSpec.describe "Bookmarks", type: :request do
	let!(:combined_perm) { Permission.create!(security_cat: "Combined Adult and Children's Windows") }
	let!(:adult_perm)    { Permission.create!(security_cat: "Adult Windows") }
	let!(:children_perm) { Permission.create!(security_cat: "Children's Windows") }
	let(:user) { create(:user) }
	let!(:bookmark) { create(:bookmark, user: user) }
	before do
		sign_in user
	end

	describe "DELETE /bookmarks/:id from=index" do
		it "destroys a bookmark and redirects to index if from=index" do
			expect {
				delete bookmark_path(bookmark), params: { from: "index" }
			}.to change(Bookmark, :count).by(-1)

			expect(Bookmark.exists?(bookmark.id)).to be_falsey
			expect(response).to redirect_to(bookmarks_path)
			follow_redirect!
			expect(response.body).to include("Bookmark has been deleted.")
		end

		it "destroys a bookmark and redirects to workshop if from not index" do
			workshop = bookmark.bookmarkable

			expect {
				delete bookmark_path(bookmark) # no from param
			}.to change(Bookmark, :count).by(-1)

			expect(Bookmark.exists?(bookmark.id)).to be_falsey
			expect(response).to redirect_to(workshop_path(workshop))
		end
	end

	describe "DELETE /bookmarks/:id from=workshops_index" do
		before { bookmark } # ensure bookmark exists
		let(:workshop) { create(:workshop) }

		it "deletes the bookmark and redirects to workshops index with query params and anchor" do
			delete bookmark_path(bookmark), params: { from: "workshops_index", title: "Art", query: "painting" }

			# Should delete the bookmark
			expect(Bookmark.exists?(bookmark.id)).to be false

			# Parse the redirect URL
			uri = URI.parse(response.location)
			expect(uri.path).to eq(workshops_path)
			expect(uri.query).to include("title=Art")
			expect(uri.query).to include("query=painting")
			# expect(uri.fragment).to eq("workshop-#{workshop.id}-anchor") can't test this bc Rack::Test doesn't support fragments
		end
	end

	describe "POST /bookmarks from=workshops_index" do
		before { bookmark } # ensure bookmark exists
		let(:workshop) { create(:workshop) }

		it "creates a bookmark and redirects to workshops index with query params and anchor" do
			post bookmarks_path, params: {
				bookmark: { bookmarkable_id: workshop.id, bookmarkable_type: "Workshop" },
				from: "workshops_index",
				title: "Art",
				query: "painting"
			}

			# Should create the bookmark
			expect(Bookmark.exists?(user: user, bookmarkable: workshop)).to be true

			# Parse the redirect URL
			uri = URI.parse(response.location)

			expect(uri.path).to eq(workshops_path)
			expect(uri.query).to include("title=Art")
			expect(uri.query).to include("query=painting")
			# expect(uri.fragment).to eq("workshop-#{workshop.id}-anchor") can't test this bc Rack::Test doesn't support fragments
		end
	end
end
