require 'rails_helper'

RSpec.describe 'Facilitators can bookmark workshops' do
  describe "Facilitator bookmarks a workshop" do
    context "when facilitator is logged in" do
      before do
        user = create(:user)
        create(:facilitator, user: user)
        adult_window = create(:windows_type, :adult)
        @workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window)

        sign_in user
        visit '/workshops'
      end

      it "allows bookmarking a workshop and displays it in bookmarks list" do
        expect(page).to have_content('Workshops')
        expect(page).to have_content('The best workshop in the world')
        # Bookmark the workshop
        within("#bookmark_icon_workshop_#{@workshop_world.id}") do
          find('button').click
        end

        expect(page).to have_content("Workshop added to your bookmarks.")

        # Navigate to bookmarks page
        visit personal_bookmarks_path
        expect(page).to have_content('My Bookmarks (1)')
        expect(page).to have_content('The best workshop in the world')
      end
    end
  end
end
