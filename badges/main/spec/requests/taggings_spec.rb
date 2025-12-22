# spec/requests/taggings_index_spec.rb
require "rails_helper"

RSpec.describe "Taggings index", type: :request do
	let!(:user) { create(:user) }

	let!(:sector_1) { create(:sector, :published, name: "Substance Abuse") }
	let!(:sector_2) { create(:sector, :published, name: "Youth") }
	let!(:category_type) { create(:category_type, name: "Theme") }
	let!(:category) do
		create(:category, :published, name: "Healing", category_type: category_type)
	end

	let!(:workshop) { create(:workshop, :published, title: "Art for Healing") }

	before do
		# Make the sector + category actually appear via joins
		create(:sectorable_item, sector: sector_2, sectorable: workshop)
		create(:categorizable_item, category: category, categorizable: workshop)

		sign_in user
	end

	describe "GET /taggings" do
		it "renders successfully" do
			get taggings_path
			expect(response).to have_http_status(:ok)
			expect(response.body).to include("Select a service population or explore tags")
		end

		it "shows sectors as buttons" do
			get taggings_path
			expect(response.body).to include(sector_1.name)
			expect(response.body).to include(sector_2.name)
		end

		it "shows categories grouped by type" do
			get taggings_path(category_names: "Healing")
			expect(response.body).to include("Theme")
			expect(response.body).to include("Healing")
		end
	end

	describe "filtering by sector_names" do
		it "filters content by sector" do
			get taggings_path(sector_names: "Youth")

			expect(response.body).to include("Youth")
			expect(response.body).to include("Art for Healing")
		end
	end

	describe "filtering by category_names" do
		it "filters content by category" do
			get taggings_path(category_names: "Healing")
			expect(response.body).to include("Theme: Healing")
			expect(response.body).to include("Art for Healing")
		end
	end

	describe "when no matching tags exist" do
		it "does not blow up and renders empty sections" do
			get taggings_path(sector_names: "Nonexistent")

			expect(response).to have_http_status(:ok)
			expect(response.body).to include("Explore all tags")
			expect(response.body).to include("No tagged items found for")
		end
	end
end
