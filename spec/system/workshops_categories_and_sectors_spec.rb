require "rails_helper"

RSpec.describe "Workshop categories & sectors", type: :system do
	let(:user) { create(:user, super_user: true) }

	before { driven_by(:rack_test) }

	describe "CREATE workshop" do
		it "assigns categories and sectors from checkboxes" do
			sign_in(user)

			windows_type = create(:windows_type, :adult)

			# Setup categories and sectors
			category_a = create(:category, :published, name: "Trauma")
			category_b = create(:category, :published, name: "Youth")
			sector_x   = create(:sector, :published, name: "Veterans")
			sector_y   = create(:sector, :published, name: "Elders")

			visit new_workshop_path

			select windows_type.short_name, from: "workshop_windows_type_id"

			# Open the dropdown accordion
			click_button "Tags"

			check "Trauma"
			check "Youth"
			check "Veterans"
			check "Elders"

			fill_in "workshop_title", with: "Category Test Workshop"
			click_on "Submit"

			workshop = Workshop.last

			expect(workshop.categories.pluck(:id)).to match_array([category_a.id, category_b.id])
			expect(workshop.sectors.pluck(:id)).to match_array([sector_x.id, sector_y.id])
		end
	end

	describe "UPDATE workshop" do
		it "removes unchecked categories and sectors" do
			sign_in(user)

			windows_type = create(:windows_type, :adult)

			cat1 = create(:category, :published, name: "A")
			cat2 = create(:category, :published, name: "B")
			sector1 = create(:sector, :published, name: "X")
			sector2 = create(:sector, :published, name: "Y")

			workshop = create(
				:workshop,
				windows_type: windows_type,
				categories: [cat1, cat2],
				sectors: [sector1, sector2],
				user: user
			)

			visit edit_workshop_path(workshop)

			# uncheck 1 category + 1 sector
			uncheck "A"
			uncheck "X"

			click_on "Submit"

			workshop.reload

			expect(workshop.categories).to match_array([cat2])
			expect(workshop.sectors).to     match_array([sector2])
		end
	end
end
