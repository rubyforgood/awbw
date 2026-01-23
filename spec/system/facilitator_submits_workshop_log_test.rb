require "rails_helper"

RSpec.describe "Facilitators can submit a workshop log" do
  describe "workshop log submission by facilitator" do
    context "when facilitator is logged in" do
      before do
        @user = create(:user)
        create(:facilitator, user: @user)

        adult_window = create(:windows_type, :adult)
        @windows_type = create(:windows_type, short_name: "COMBINED")

        @form_builder = FormBuilder.create!(windows_type_id: @windows_type.id, name: "The form")
        @form_builder.forms.create!

        create(:workshop, title: 'The best workshop in the world', windows_type: adult_window, featured: true)
        create(:workshop, title: 'The best workshop on mars', windows_type: adult_window, featured: true)

        @project = create(:project, name: "Test Project", windows_type_id: @windows_type.id)
        ProjectUser.create!(user: @user, project: @project, position: :default)

        sign_in @user
        visit new_workshop_log_path
      end
      it "successfully submits a complete workshop log" do
        expect(page).to have_content("New Workshop log")
        select "The best workshop in the world", from: "workshop_log[workshop_id]"
        select @project.name, from: "workshop_log[project_id]"
        fill_in "workshop_log[date]", with: 1.day.ago.strftime("%m-%d-%Y")

        fill_in "workshop_log_children_ongoing", with: "5"
        fill_in "workshop_log_teens_ongoing", with: "3"
        fill_in "workshop_log_adults_ongoing", with: "10"
        fill_in "workshop_log_children_first_time", with: "2"
        fill_in "workshop_log_teens_first_time", with: "1"
        fill_in "workshop_log[adults_first_time]", with: "4"


        click_link "Add Quote"
        quote_fields = page.all("textarea[name*='[quote_attributes][quote]']")
        quote_fields.last.set("This workshop helped me express feelings I couldn't put into words")

        age_fields = page.all("input[name*='[quote_attributes][age]']")
        age_fields.last.set("32")
        # second quote
        click_link "Add Quote"
        quote_fields = page.all("textarea[name*='[quote_attributes][quote]']")
        quote_fields.last.set("Art has given me a new voice for my emotions")

        age_fields = page.all("input[name*='[quote_attributes][age]']")
        age_fields.last.set("teen")

        remove_links = page.all('a', text: "Delete")
        remove_links.last.click if remove_links.count >= 2

        expect(page).not_to have_content("Art has given me a new voice")


        # Upload a file
        find("#workshop_log_gallery_assets_attributes_0_file", visible: :all)
          .set(Rails.root.join('spec/fixtures/some_file.png'))
        # second file
        click_link "Add another file"
        expect(page).to have_css('input[type="file"]', minimum: 2, visible: :all)
        file_inputs = page.all('input[type="file"]', visible: :all)
        file_inputs.last.set(Rails.root.join('spec/fixtures/some_file1.png'))
        # Submit
        click_button "Save Log"
        expect(page).to have_content("Thank you for submitting a workshop log")
      end

      it "validates required fields individually" do
        visit new_workshop_log_path

        #  Missing project
        select "The best workshop in the world", from: "workshop_log[workshop_id]"
        fill_in "workshop_log[date]", with: 1.day.ago.strftime("%m-%d-%Y")
        select "", from: "workshop_log[project_id]"
        click_button "Save Log"
        expect(page).to have_content("Project must exist")

        # Missing workshop
        visit new_workshop_log_path
        select @project.name, from: "workshop_log[project_id]"
        fill_in "workshop_log[date]", with: 1.day.ago.strftime("%m-%d-%Y")
        click_button "Save Log"
        expect(page).to have_content("Workshop must exist")

        # Missing date
        visit new_workshop_log_path
        select "The best workshop in the world", from: "workshop_log[workshop_id]"
        select @project.name, from: "workshop_log[project_id]"
        click_button "Save Log"
        expect(page).to have_content("Date can't be blank")
      end
    end
  end
end
