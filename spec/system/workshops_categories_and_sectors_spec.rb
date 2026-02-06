# spec/system/workshops_categories_and_sectors_spec.rb
require "rails_helper"

RSpec.describe "Workshop categories & sectors", type: :system do
  let(:admin) { create(:user, :admin) }

  before do
    driven_by(:selenium_chrome_headless)
  end

  describe "CREATE workshop" do
    it "assigns categories and sectors from checkboxes" do
      sign_in(admin)

      windows_type  = create(:windows_type, :adult)
      category_type = create(:category_type, :published, name: "Focus")

      # Categories must be published AND belong to a published type
      category_a = create(:category, :published, name: "Trauma", category_type: category_type)
      category_b = create(:category, :published, name: "Youth",  category_type: category_type)

      # Sectors must be published
      sector_x = create(:sector, :published, name: "Veterans")
      sector_y = create(:sector, :published, name: "Elders")

      visit new_workshop_path

      fill_in "workshop_title", with: "Category Test Workshop"
      select windows_type.short_name, from: "workshop_windows_type_id"

      # Open Tags accordion
      click_button "Tags"

      # Target actual checkbox inputs directly
      find("#workshop_category_ids_#{category_a.id}", visible: :all).check
      find("#workshop_category_ids_#{category_b.id}", visible: :all).check
      find("#workshop_sector_ids_#{sector_x.id}",     visible: :all).check
      find("#workshop_sector_ids_#{sector_y.id}",     visible: :all).check

      pre_workshop_count = Workshop.count
      click_button "Submit"
      post_workshop_count = Workshop.count
      expect(post_workshop_count).to eq(pre_workshop_count + 1)

      workshop = Workshop.last

      expect(workshop.categories).to match_array([ category_a, category_b ])
      expect(workshop.sectors).to match_array([ sector_x, sector_y ])
    end
  end

  describe "UPDATE workshop" do
    it "removes unchecked categories and sectors" do
      sign_in(admin)

      windows_type  = create(:windows_type, :adult)
      category_type = create(:category_type, :published, name: "Focus")

      cat1 = create(:category, :published, name: "A", category_type: category_type)
      cat2 = create(:category, :published, name: "B", category_type: category_type)

      sector1 = create(:sector, :published, name: "X")
      sector2 = create(:sector, :published, name: "Y")

      workshop =
        create(
          :workshop,
          windows_type: windows_type,
          categories: [ cat1, cat2 ],
          sectors: [ sector1, sector2 ],
          user: admin
        )

      visit edit_workshop_path(workshop)

      click_button "Tags"

      # Uncheck actual inputs directly
      find("#workshop_category_ids_#{cat1.id}", visible: :all).uncheck
      find("#workshop_sector_ids_#{sector1.id}", visible: :all).uncheck

      click_button "Save changes"

      workshop.reload

      expect(workshop.categories).to match_array([ cat2 ])
      expect(workshop.sectors).to match_array([ sector2 ])
    end
  end
end
