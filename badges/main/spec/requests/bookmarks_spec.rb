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

	describe "DELETE /bookmarks/:id" do
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
end
