
require 'rails_helper'

RSpec.describe "Facilitators can submit a workshop idea", type: :system do
  describe "Navigate to Workshop Idea page" do
    context "When Facilitator is logged in" do
      before do
        create(:windows_type, :adult)
        create(:windows_type, :children)
        create(:windows_type, :combined)

        user = create(:user)
        create(:facilitator, user: user)
        sign_in user

        visit new_workshop_idea_path
      end

      it "shows the new workshop form" do
        expect(page).to have_content("New Workshop idea")
      end

      it "submits the form when clicking Submit" do
        fill_in 'workshop_idea_title', with: 'My Amazing Workshop'
        select 'ADULT WINDOWS', from: 'workshop_idea_windows_type_id'
        # select 'Adult', from:'workshop_idea_age_range'
        fill_in 'workshop_idea_objective', with: 'Learn something new'
        fill_in 'workshop_idea_description', with: 'This is a test workshop description.'
        fill_in 'workshop_idea_materials', with: 'Paper, markers'
        fill_in 'workshop_idea_optional_materials', with: 'Scissors, glue'
        fill_in 'workshop_idea_setup', with: 'Arrange tables'
        fill_in 'workshop_idea_introduction', with: 'Start with a story'
        fill_in 'workshop_idea_time_intro', with: 10
        fill_in 'workshop_idea_opening_circle', with: 'Welcome and warm up'
        fill_in 'workshop_idea_time_opening_circle', with: 5
        fill_in 'workshop_idea_demonstration', with: 'Show how it works'
        fill_in 'workshop_idea_time_demonstration', with: 15
        fill_in 'workshop_idea_warm_up', with: 'Stretching and breathing'
        fill_in 'workshop_idea_time_warm_up', with: 5
        fill_in 'workshop_idea_creation', with: 'Hands-on creation'
        fill_in 'workshop_idea_time_creation', with: 30
        fill_in 'workshop_idea_closing', with: 'Reflection and clean up'
        fill_in 'workshop_idea_time_closing', with: 10
        fill_in 'workshop_idea_notes', with: 'Some notes'
        fill_in 'workshop_idea_tips', with: 'Some tips'
        attach_file('workshop_primary_media', Rails.root.join('spec/fixtures/some_file.png')) if page.has_field?('workshop_idea_primary_asset_attributes_file')
        # Submit
        click_button 'Submit'
        expect(page).to have_content('Workshop idea was successfully created')
      end

      it "cancels the form when clicking Cancel" do
        fill_in 'workshop_idea_title', with: 'My unsubmitted Workshop'
        select 'ADULT WINDOWS', from: 'workshop_idea_windows_type_id'
        # select 'Adult', from:'workshop_idea_age_range'
        fill_in 'workshop_idea_objective', with: 'Learn nothing new'
        fill_in 'workshop_idea_description', with: 'This is a test workshop description.'
        fill_in 'workshop_idea_materials', with: 'Paper, markers'
        fill_in 'workshop_idea_optional_materials', with: 'Scissors, glue'
        fill_in 'workshop_idea_setup', with: 'Arrange tables'
        fill_in 'workshop_idea_introduction', with: 'Start with a story'
        fill_in 'workshop_idea_time_intro', with: 10
        fill_in 'workshop_idea_opening_circle', with: 'Welcome and warm up'
        fill_in 'workshop_idea_time_opening_circle', with: 5
        fill_in 'workshop_idea_demonstration', with: 'Show how it works'
        fill_in 'workshop_idea_time_demonstration', with: 15
        fill_in 'workshop_idea_warm_up', with: 'Stretching and breathing'
        fill_in 'workshop_idea_time_warm_up', with: 5
        fill_in 'workshop_idea_creation', with: 'Hands-on creation'
        fill_in 'workshop_idea_time_creation', with: 30
        fill_in 'workshop_idea_closing', with: 'Reflection and clean up'
        fill_in 'workshop_idea_time_closing', with: 10
        fill_in 'workshop_idea_notes', with: 'Some notes'
        fill_in 'workshop_idea_tips', with: 'Some tips'
        attach_file('workshop_primary_media', Rails.root.join('spec/fixtures/some_file.png')) if page.has_field?('workshop_idea_primary_asset_attributes_file')
        # Cancel
        click_link 'Cancel'
        expect(page).to have_content('Featured Workshops')
        expect(page).to have_content('Community News')
      end
    end
  end
end
