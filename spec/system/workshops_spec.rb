require 'rails_helper'

RSpec.describe "Workshops" do
  describe 'workshop index' do
    context "When user is logged in" do
      it 'User sees overview of workshops' do
        sign_in(create(:user))
  
        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window)
        workshop_mars = create(:workshop, title: 'The best workshop on mars', windows_type: adult_window)
        workshop_hello = create(:workshop, title: 'oh hello!', windows_type: adult_window)
  
        visit workshops_path

        within('#workshops-list') do
          expect(page).to have_content(workshop_world.title)
          expect(page).to have_content(workshop_mars.title)
          expect(page).to have_content(workshop_hello.title)
        end
      end

      it 'User can search for a workshop' do
        user = create(:user)
        sign_in(user)
  
        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window)
        workshop_mars = create(:workshop, title: 'The best workshop on mars', windows_type: adult_window)
        workshop_hello = create(:workshop, title: 'oh hello!', windows_type: adult_window)
  
        visit workshops_path

        fill_in 'query', with: 'best workshop'
        check("windows_types_#{adult_window.id}")

        within('#workshops-list') do
          expect(page).to have_content(workshop_world.title)
          expect(page).to have_content(workshop_mars.title)
          # expect(page).not_to have_content(workshop_hello.title) # TODO - get this working again once the page autosubmits
        end
      end
    end
  end

  describe 'view workshops' do
    context "When user is logged in" do
      it "User sees workshop details" do
        sign_in(create(:user))
        
        workshop = create(:workshop, title: 'The best workshop in the world. This is a tribute.')
  
        visit workshop_path(workshop)
  
        expect(page).to have_css(".inner-hero", text: 'The best workshop in the world. This is a tribute.')
      end
    end
  end

  describe 'create workshop' do
    context "When super user is logged in" do
      it "Super user can create a new workshop" do
        user = create(:user, super_user: true)
        sign_in(user)
        adult_window = create(:windows_type, :adult)

        visit new_workshop_path(windows_type_id: adult_window.id)

        save_and_open_page

        fill_in 'Workshop title', with: 'My New Workshop'
        select adult_window.short_name, from: 'workshop_windows_type_id'
        fill_in 'workshop_full_name', with: 'Jane Doe'
        fill_in 'workshop_objective', with: 'Learn something new'
        fill_in 'workshop_materials', with: 'Paper, Markers'
        fill_in 'workshop_setup', with: 'Arrange tables'
        fill_in 'workshop_demonstration', with: 'Show example'
        fill_in 'workshop_warm_up', with: 'Stretching'
        fill_in 'workshop_creation', with: 'Step 1, Step 2'

        click_on 'Submit'

        expect(Workshop.last.title).to eq('My New Workshop')
        # expect(page).to have_content('My New Workshop')
        # expect(page).to have_content('Learn something new')
      end
    end
  end

  describe 'edit workshop' do
    context "When super user is logged in" do
      it "Super user can edit an existing workshop" do
        user = create(:user, super_user: true)
        sign_in(user)
        adult_window = create(:windows_type, :adult)
        workshop = create(:workshop, title: 'Old Title', windows_type: adult_window, user: user)

        visit edit_workshop_path(workshop)

        fill_in 'Workshop title', with: 'Updated Title'
        click_on 'Submit'

        expect(workshop.reload.title).to eq('Updated Title')
        expect(page).to have_content('Workshop updated successfully.')
      end
    end
  end
end
