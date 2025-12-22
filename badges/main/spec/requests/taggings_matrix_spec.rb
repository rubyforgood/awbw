require "rails_helper"

RSpec.describe "Taggings matrix", type: :request do
	let!(:admin) { create(:user, :admin) }

	let!(:sector) { create(:sector, :published, name: "Youth") }
	let!(:category_type) { create(:category_type, name: "Theme") }
	let!(:category) do
		create(:category, :published, name: "Healing", category_type: category_type)
	end

	let!(:workshop) do
		create(:workshop, :published, title: "Art for Healing")
	end

	before do
		# Wire taggings so counts exist
		create(:sectorable_item, sector: sector, sectorable: workshop)
		create(:categorizable_item, category: category, categorizable: workshop)

		sign_in admin
	end

	describe "GET /taggings/matrix" do
		it "renders successfully" do
			get taggings_matrix_path
			expect(response).to have_http_status(:ok)
		end

		it "shows the page header" do
			get taggings_matrix_path

			expect(response.body).to include("Tagging counts")
			expect(response.body).to include("Total tagged items by service population and category")
		end

		it "renders sector and category sections" do
			get taggings_matrix_path

			expect(response.body).to include("Service populations")
			expect(response.body).to include("Categories")
		end

		it "shows published sectors and categories" do
			get taggings_matrix_path

			expect(response.body).to include("Youth")
			expect(response.body).to include("Healing")
		end

		it "renders a column for each taggable model" do
			get taggings_matrix_path

			Tag::TAGGABLE_META.keys.each do |key|
				expect(response.body).to include(key.to_s.humanize)
			end
		end

		it "shows counts for tagged records" do
			get taggings_matrix_path

			# Workshop count should be 1 for both sector + category
			expect(response.body).to include(">1<")
		end

		it "renders links when count is positive" do
			get taggings_matrix_path

			expect(response.body).to include("/taggings?")
		end
	end

	context "when no taggings exist" do
		before do
			SectorableItem.delete_all
			CategorizableItem.delete_all
		end

		it "renders zeros and does not error" do
			get taggings_matrix_path

			expect(response).to have_http_status(:ok)
			expect(response.body).to include("0")
		end
	end
end
