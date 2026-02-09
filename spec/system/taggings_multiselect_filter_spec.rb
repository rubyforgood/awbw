require 'rails_helper'

RSpec.describe 'Taggings multiselect filter', type: :system, js: true do
  let(:user) { create(:user) }
  let!(:person) { create(:person, user: user) }

  # Create sectors
  let!(:sector_youth) { create(:sector, :published, name: "Youth") }
  let!(:sector_adult) { create(:sector, :published, name: "Adult") }
  let!(:sector_veterans) { create(:sector, :published, name: "Veterans") }

  # Create categories
  let!(:category_type_theme) { create(:category_type, :published, name: "Theme") }
  let!(:category_healing) { create(:category, :published, name: "Healing", category_type: category_type_theme) }
  let!(:category_trauma) { create(:category, :published, name: "Trauma", category_type: category_type_theme) }

  # Create workshops with tags
  let!(:workshop_youth_healing) do
    workshop = create(:workshop, :published, title: "Youth Healing Workshop")
    create(:sectorable_item, sector: sector_youth, sectorable: workshop)
    create(:categorizable_item, category: category_healing, categorizable: workshop)
    workshop
  end

  let!(:workshop_adult_trauma) do
    workshop = create(:workshop, :published, title: "Adult Trauma Workshop")
    create(:sectorable_item, sector: sector_adult, sectorable: workshop)
    create(:categorizable_item, category: category_trauma, categorizable: workshop)
    workshop
  end

  let!(:workshop_youth_adult_healing) do
    workshop = create(:workshop, :published, title: "Combined Youth Adult Healing Workshop")
    create(:sectorable_item, sector: sector_youth, sectorable: workshop)
    create(:sectorable_item, sector: sector_adult, sectorable: workshop)
    create(:categorizable_item, category: category_healing, categorizable: workshop)
    workshop
  end

  before do
    sign_in user
  end

  describe 'on taggings index page' do
    before do
      visit taggings_path
    end

    it 'displays the explore by combination section' do
      expect(page).to have_content(/explore by combination/i)
      expect(page).to have_content('Service Population')
      expect(page).to have_content('Category')
      expect(page).to have_button('Apply combination filters')
    end

    it 'displays all available sectors as checkboxes' do
      expect(page).to have_field('sector_names_all[]', with: 'Youth')
      expect(page).to have_field('sector_names_all[]', with: 'Adult')
      expect(page).to have_field('sector_names_all[]', with: 'Veterans')
    end

    it 'displays all available categories as checkboxes' do
      expect(page).to have_field('category_names_all[]', with: 'Healing')
      expect(page).to have_field('category_names_all[]', with: 'Trauma')
    end

    it 'allows selecting a single sector and filtering results' do
      check 'Youth'
      click_button 'Apply combination filters'

      expect(page).to have_current_path(taggings_path(sector_names_all: 'Youth'))
      expect(page).to have_content('Youth')
      expect(page).to have_content('Youth Healing Workshop')
      expect(page).to have_content('Combined Youth Adult Healing Workshop')
      expect(page).not_to have_content('Adult Trauma Workshop')
    end

    it 'allows selecting a single category and filtering results' do
      check 'Healing'
      click_button 'Apply combination filters'

      expect(page).to have_current_path(taggings_path(category_names_all: 'Healing'))
      expect(page).to have_content('Theme: Healing')
      expect(page).to have_content('Youth Healing Workshop')
      expect(page).to have_content('Combined Youth Adult Healing Workshop')
      expect(page).not_to have_content('Adult Trauma Workshop')
    end

    it 'allows selecting multiple sectors with AND logic' do
      check 'Youth'
      check 'Adult'
      click_button 'Apply combination filters'

      # The order might be alphabetical (Adult--Youth) or as selected (Youth--Adult)
      expect(page.current_path).to eq(taggings_path)
      expect(page.current_url).to match(/sector_names_all=(Adult--Youth|Youth--Adult)/)
      # Only the workshop with BOTH Youth and Adult tags should appear
      expect(page).to have_content('Combined Youth Adult Healing Workshop')
      expect(page).not_to have_content('Youth Healing Workshop')
      expect(page).not_to have_content('Adult Trauma Workshop')
    end

    it 'allows selecting both sectors and categories with AND logic' do
      check 'Youth'
      check 'Healing'
      click_button 'Apply combination filters'

      expect(page).to have_current_path(taggings_path(sector_names_all: 'Youth', category_names_all: 'Healing'))
      expect(page).to have_content('Youth')
      expect(page).to have_content('Theme: Healing')
      # Only workshops with BOTH Youth and Healing tags should appear
      expect(page).to have_content('Youth Healing Workshop')
      expect(page).to have_content('Combined Youth Adult Healing Workshop')
      expect(page).not_to have_content('Adult Trauma Workshop')
    end

    it 'preserves selected checkboxes when returning to the page with filters' do
      visit taggings_path(sector_names_all: 'Youth--Adult', category_names_all: 'Healing')

      expect(page).to have_checked_field('Youth')
      expect(page).to have_checked_field('Adult')
      expect(page).to have_checked_field('Healing')
      expect(page).not_to have_checked_field('Veterans')
      expect(page).not_to have_checked_field('Trauma')
    end

    it 'shows empty state when no items match the filter combination' do
      check 'Veterans'
      check 'Healing'
      click_button 'Apply combination filters'

      expect(page).to have_content('No items have this tag combination')
    end

    it 'clears filters and returns to unfiltered state when no checkboxes are selected' do
      # First apply some filters
      visit taggings_path(sector_names_all: 'Youth')
      expect(page).to have_content('Youth Healing Workshop')

      # Then uncheck all and apply
      uncheck 'Youth'
      click_button 'Apply combination filters'

      expect(page).to have_current_path(taggings_path)
      expect(page).to have_content('Select a service population or explore tags')
    end
  end

  describe 'on tags index page' do
    before do
      visit tags_path
    end

    it 'displays the explore by combination section at the bottom' do
      expect(page).to have_content('Tags')
      expect(page).to have_content(/explore by combination/i)
      expect(page).to have_content('Service Population')
      expect(page).to have_content('Category')
      expect(page).to have_button('Apply combination filters')
    end

    it 'allows selecting sectors and redirects to taggings page with filters' do
      check 'Youth'
      check 'Adult'
      click_button 'Apply combination filters'

      # The order might be alphabetical (Adult--Youth) or as selected (Youth--Adult)
      expect(page.current_path).to eq(taggings_path)
      expect(page.current_url).to match(/sector_names_all=(Adult--Youth|Youth--Adult)/)
      expect(page).to have_content('Combined Youth Adult Healing Workshop')
    end

    it 'allows selecting categories and redirects to taggings page with filters' do
      check 'Healing'
      click_button 'Apply combination filters'

      expect(page).to have_current_path(taggings_path(category_names_all: 'Healing'))
      expect(page).to have_content('Youth Healing Workshop')
    end
  end
end
