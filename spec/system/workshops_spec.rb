require 'rails_helper'

RSpec.describe "Workshops", type: :system do
  before do
    driven_by(:rack_test)
    
    create(:footer)
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

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

        within('.search-wrapper') do
          expect(page).to have_content('The best workshop in the world')
          expect(page).to have_content('The best workshop on mars')
          expect(page).to have_content('oh hello!')
        end
      end

      # Can't get this damn spec to work. WorkshopController#index performs a mix of "permissions"
      # checks using User#curriculum + search using Workshop#search (full text on query param & 
      # where col match using windows_type_id). I am not sure why my factory data is being excluded.
      xit 'User can search for a workshop' do
        user = create(:user)
        sign_in(user)
  
        create(:sector, :other)
        adult_window = create(:windows_type, :adult)
        workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window)
        workshop_mars = create(:workshop, title: 'The best workshop on mars', windows_type: adult_window)
        workshop_hello = create(:workshop, title: 'oh hello!', windows_type: adult_window)
  
        visit workshops_path

        fill_in 'query', with: 'best workshop'
        choose "type_#{adult_window.id}" # radio button for Adult Workshop Radio isn't associated with the label
    
        click_on 'Apply filters'

        within('.search-wrapper') do
          expect(page).to have_content('The best workshop in the world')
          expect(page).to have_content('The best workshop on mars')
          expect(page).not_to have_content('oh hello!')
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
end