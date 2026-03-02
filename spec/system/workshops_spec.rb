require 'rails_helper'

RSpec.describe "Workshops", type: :system do
  describe 'workshop index' do
    context "When user is logged in" do
      it 'User sees overview of workshops' do
        sign_in(create(:user))

        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        workshop_world = create(:workshop, :published, title: 'The best workshop in the world', windows_type: adult_window)
        workshop_mars = create(:workshop, :published, title: 'The best workshop on mars', windows_type: adult_window)
        workshop_hello = create(:workshop, :published, title: 'oh hello!', windows_type: adult_window)

        visit workshops_path

        expect(page).to have_content(workshop_world.title)
        expect(page).to have_content(workshop_mars.title)
        expect(page).to have_content(workshop_hello.title)
      end

      it 'User can search for a workshop' do
        user = create(:user)
        sign_in(user)

        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        workshop_world = create(:workshop, :published, title: 'The best workshop in the world', windows_type: adult_window, rhino_objective: "test")
        workshop_mars = create(:workshop, :published, title: 'The best workshop on mars', windows_type: adult_window, rhino_objective: "test")
        workshop_hello = create(:workshop, :published, title: 'oh hello!', windows_type: adult_window, rhino_objective: "test")

        visit workshops_path

        fill_in 'query', with: 'best workshop'

        # Open the dropdown
        click_on "Windows Audience"  # this clicks the <button> text/label
        check("windows_types_#{adult_window.id}")

        expect(page).to have_content(workshop_world.title)
        expect(page).to have_content(workshop_mars.title)
        expect(page).not_to have_content(workshop_hello.title)
      end

      it 'User clears checkbox and text filters and sees all results again' do
        user = create(:user)
        sign_in(user)

        sector = create(:sector, :published, name: "Health")
        category_type = create(:category_type, :published, name: "Themes")
        category = create(:category, :published, name: "Healing", category_type: category_type)
        adult_window = create(:windows_type, :adult)
        children_window = create(:windows_type, :children)

        workshop_adult = create(:workshop, :published, title: 'Adult Healing Workshop',
                                windows_type: adult_window, sectors: [ sector ], categories: [ category ],
                                rhino_objective: "test")
        workshop_child = create(:workshop, :published, title: 'Children Fun Workshop',
                                windows_type: children_window, rhino_objective: "test")

        visit workshops_path

        expect(page).to have_content(workshop_adult.title)
        expect(page).to have_content(workshop_child.title)

        # Filter by text
        fill_in 'title', with: 'Adult'
        expect(page).to have_content(workshop_adult.title)
        expect(page).not_to have_content(workshop_child.title)

        # Also check a sector checkbox
        click_on "Sector"
        check("sectors_#{sector.id}")
        expect(page).to have_content(workshop_adult.title)

        # Also check a windows type checkbox
        click_on "Windows Audience"
        check("windows_types_#{adult_window.id}")
        expect(page).to have_content(workshop_adult.title)

        # Clear all filters
        click_link "Clear filters"

        # Both workshops should reappear
        expect(page).to have_content(workshop_adult.title)
        expect(page).to have_content(workshop_child.title)

        # Text field should be empty
        expect(find_field('title').value).to eq('')

        # Checkboxes should be unchecked
        expect(find("#sectors_#{sector.id}", visible: :all)).not_to be_checked
        expect(find("#windows_types_#{adult_window.id}", visible: :all)).not_to be_checked
      end
    end
  end

  describe 'view workshops' do
    context "When user is logged in" do
      it "User sees workshop details" do
        sign_in(create(:user))

        workshop = create(:workshop, :published, title: 'The best workshop in the world. This is a tribute.')

        visit workshop_path(workshop)

        expect(page).to have_content(workshop.title)
      end
    end
  end

  describe 'create workshop' do
    context "When admin is logged in" do
      it "Admin can create a new workshop", js: true do
        user = create(:user, :admin)
        sign_in(user)
        adult_window = create(:windows_type, :adult)

        visit new_workshop_path(windows_type_id: adult_window.id)

        fill_in "workshop_title", with: 'My New Workshop'
        select adult_window.short_name, from: 'workshop_windows_type_id'
        find("#workshop_published", visible: :all).check
        find('#body-button').click

        click_on 'Submit'

        # expect(Workshop.last.title).to eq('My New Workshop')
        expect(page).to have_content('My New Workshop')
        # expect(page).to have_content('Learn something new')
      end
    end
  end

  describe 'edit workshop' do
    context "When admin is logged in" do
      it "Admin can edit an existing workshop" do
        user = create(:user, :admin)
        sign_in(user)
        adult_window = create(:windows_type, :adult)
        workshop = create(:workshop, title: "Old Title", windows_type: adult_window, created_by: user)

        visit edit_workshop_path(workshop)

        fill_in "workshop_title", with: "A New Title"
        select adult_window.short_name, from: "Windows audience" # windows_type required

        click_on 'Save changes'

        # expect(workshop.reload.title).to eq("A New Title")
        expect(page).to have_content("A New Title")
        expect(page).to have_content("Workshop updated successfully.")
      end
    end
  end
end
