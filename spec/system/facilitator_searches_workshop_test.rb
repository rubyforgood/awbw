require 'rails_helper'

RSpec.describe 'Facilitators can search for a workshop' do
  describe "Facilitator searches a workshop" do
    context "when facilitator is logged in" do
      before do
        user = create(:user)
        create(:facilitator, user: user)

        adult_window = create(:windows_type, :adult)
        workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window)
        workshop_mars = create(:workshop, title: 'The best workshop on mars', windows_type: adult_window)
        workshop_hello = create(:workshop, title: 'oh hello!', windows_type: adult_window)

        sign_in user
        visit '/'
      end

      it "navigate to workshops from nav" do
        expect(page).to have_content("Curriculum")
        click_button('facilitate_button')

        within '#curriculum_menu' do
          click_link('Workshops')
        end
        expect(page).to have_current_path(workshops_path)
        expect(page).to have_content('Workshops')
        expect(page).to have_content('KEYWORD SEARCH FILTERS')

        expect(page).to have_content('The best workshop in the world')
        expect(page).to have_content('The best workshop on mars')
        expect(page).to have_content('oh hello!')
      end

      it "searches for workshop with 'world' keyword" do
        visit workshops_path
        fill_in 'title', with: "world"
        expect(page).to have_content('The best workshop in the world')
        expect(page).to have_no_content("The best workshop on mars")
        expect(page).to have_no_content("oh hello!")
      end

      it "searches for workshop with 'mars' keyword" do
        visit workshops_path
        fill_in 'title', with: "mars"
        expect(page).to have_content('The best workshop on mars')
        expect(page).to have_no_content("The best workshop in the world")
        expect(page).to have_no_content("oh hello!")
      end

      it "searches for workshop with 'hello' keyword" do
        visit workshops_path
        fill_in 'title', with: "hello"
        expect(page).to have_content('oh hello!')
        expect(page).to have_no_content("The best workshop in the world")
        expect(page).to have_no_content("The best workshop on mars")
      end

      it "searches for workshop with 'the best' keyword for multiple results" do
       visit workshops_path
       fill_in 'title', with: "the best"
       expect(page).to have_content("The best workshop in the world")
       expect(page).to have_content("The best workshop on mars")
       expect(page).to have_no_content('oh hello!')
     end

      it "shows no results for non-matching search" do
       visit workshops_path
       fill_in 'title', with: "nonexistent"
       expect(page).to have_no_content('The best workshop in the world')
       expect(page).to have_no_content('The best workshop on mars')
       expect(page).to have_no_content('oh hello!')
       expect(page).to have_content('Your search returned no results. Please try again.')
     end

      it "shows all workshops when search is cleared" do
        visit workshops_path
        fill_in 'title', with: ""
        expect(page).to have_content('The best workshop in the world')
        expect(page).to have_content("The best workshop on mars")
        expect(page).to have_content("oh hello!")
      end
    end
  end
end
