require 'rails_helper'

RSpec.describe "People can submit a workshop idea", type: :system do
  describe "Navigate to Workshop Idea page" do
    context "When Person is logged in" do
      let!(:adult_windows_type) { create(:windows_type, :adult) }
      let!(:children_windows_type) { create(:windows_type, :children) }
      let!(:combined_windows_type) { create(:windows_type, :combined) }

      let(:user) { create(:user, :admin) }

      before do
        Capybara.current_session.current_window.resize_to(1920, 5000)
        create(:person, user: user)
        sign_in user
        visit new_workshop_idea_path
      end

      it "shows the new workshop form" do
        expect(page).to have_content("New Workshop Idea")
      end

      it "submits the form successfully when all required fields are filled" do
        fill_in 'workshop_idea_title', with: 'My Amazing Workshop'
        select 'ADULT', from: 'workshop_idea_windows_type_id'

        click_button 'Submit'
        expect(page).to have_content('Workshop idea was successfully created')
        expect(page).to have_current_path(workshop_idea_path(WorkshopIdea.last))
      end

      it "cancels the form when clicking Cancel" do
        fill_in 'workshop_idea_title', with: 'My unsubmitted Workshop'
        select 'ADULT', from: 'workshop_idea_windows_type_id'

        click_link 'Cancel'
        expect(page).to have_current_path(workshop_ideas_path)
        expect(page).to have_content('Workshop ideas')
      end

      context "validation errors" do
        it "shows a validation error when title is missing" do
          select 'ADULT', from: 'workshop_idea_windows_type_id'

          click_button 'Submit'

          expect(page).to have_content("can't be blank").or have_content("Title can't be blank")
          expect(page).not_to have_content('Workshop idea was successfully created')
        end

        it "shows a validation error when windows audience is missing" do
          fill_in 'workshop_idea_title', with: 'Workshop Without Audience'

          click_button 'Submit'

          expect(page).to have_content("Windows type must exist")
          expect(page).not_to have_content('Workshop idea was successfully created')
        end

        it "shows validation errors when all required fields are missing" do
          click_button 'Submit'

          expect(page).to have_css('[data-field="errors"], .errors, #error_explanation, [class*="error"]')
          expect(page).not_to have_content('Workshop idea was successfully created')
        end
        it "shows a validation error when an invalid file type is attached" do
          fill_in 'workshop_idea_title', with: 'Workshop With Bad File'
          select 'ADULT', from: 'workshop_idea_windows_type_id'

          attach_file(
            Rails.root.join('spec/fixtures/files/sample.txt'),
            make_visible: true
          )

          click_button 'Submit'
          expect(page).to have_content("File type not accepted")
          expect(page).to have_content("Gallery assets file type not accepted")
        end
      end
    end
  end
end
