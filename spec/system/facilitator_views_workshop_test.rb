require 'rails_helper'

RSpec.describe "Facilitators can view a workshop" do
  describe 'workshops views' do
    context "When facilitator is logged in" do
      before do
        user = create(:user)
        create(:facilitator, user: user)
        adult_window = create(:windows_type, :adult)
        @workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window)
        @workshop_mars = create(:workshop, title: 'The best workshop on mars', windows_type: adult_window, featured: true, objective: 'take everyone to mars', materials: 'rocket', setup: 'make a rocket')
        sign_in user
      end

      it 'views workshop via dashboard' do
        visit '/'

        expect(page).to have_content('The best workshop on mars')

        find('span', text: 'The best workshop on mars').click

        expect(page).to have_current_path(workshop_path(@workshop_mars))

        expect(page).to have_css('h1', text: 'The best workshop on mars')
        # expect(page).to have_content("Author: #{@workshop_mars.author}")
        expect(page).to have_content("Author:")
        expect(page).to have_content("Category: #{@workshop_mars.windows_type&.short_name}")
        expect(page).to have_content("Added: #{@workshop_mars.created_at.strftime('%B %Y')}")
        expect(page).to have_link('Details')

        within '#english-content' do
          expect(page).to have_content('Objective')
          expect(page).to have_content('Materials')
          expect(page).to have_content('Setup')
        end
      end

      it 'views workshop from search' do
        visit workshops_path

        fill_in 'title', with: 'world'
        expect(page).to have_content('The best workshop in the world')


        find('span', text: 'The best workshop in the world').click

        expect(page).to have_current_path(workshop_path(@workshop_world))
        expect(page).to have_css('h1', text: 'The best workshop in the world')
        # expect(page).to have_content("Author: #{@workshop_world.author}")
        expect(page).to have_content("Author:")
        expect(page).to have_content("Category: #{@workshop_world.windows_type&.short_name}")
        expect(page).to have_content("Added: #{@workshop_world.created_at.strftime('%B %Y')}")
        expect(page).to have_link('Details')
      end

      it 'views workshop from bookmarks' do
        visit '/workshops'
        expect(page).to have_content('Workshops')
        expect(page).to have_content('The best workshop in the world')
        # Bookmark the workshop
        within("#bookmark_icon_workshop_#{@workshop_world.id}") do
          find('button').click
        end

        expect(page).to have_content("Workshop added to your bookmarks.")

        visit personal_bookmarks_path
        expect(page).to have_content('My Bookmarks (1)')
        expect(page).to have_content('The best workshop in the world')

        find('a', text: 'The best workshop in the world').click

        expect(page).to have_current_path(workshop_path(@workshop_world))
        expect(page).to have_css('h1', text: 'The best workshop in the world')
        # expect(page).to have_content("Author: #{@workshop_world.author}")
        expect(page).to have_content("Author:")
        expect(page).to have_content("Category: #{@workshop_world.windows_type&.short_name}")
        expect(page).to have_content("Added: #{@workshop_world.created_at.strftime('%B %Y')}")
        expect(page).to have_link('Details')
      end
    end
  end
end
