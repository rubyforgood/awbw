require "rails_helper"

RSpec.describe "Facilitators can view a submitted workshop log" do
  describe "when facilitator is logged in" do
    context "viewing workshop logs" do
      before do
        Capybara.current_session.current_window.resize_to(1920, 5000)

        @user = create(:user)
        create(:facilitator, user: @user)
        windows_type = create(:windows_type, short_name: "COMBINED")

        form_builder = FormBuilder.create!(windows_type_id: windows_type.id, name: "The form")
        form_builder.forms.create!

        @workshop1 = create(:workshop, title: 'The best workshop in the world', windows_type: windows_type, featured: true)
        @workshop2 = create(:workshop, title: 'Art therapy for beginners', windows_type: windows_type, featured: false)

        @project = create(:project, name: "Test Project", windows_type_id: windows_type.id)
        ProjectUser.create!(user: @user, project: @project, position: :default, title: "Project user")

        @workshop_log1 = create(:workshop_log,
          workshop_id: @workshop1.id,
          project_id: @project.id,
          user_id: @user.id,
          date: 1.day.ago,
          adults_first_time: 4,
          adults_ongoing: 10,
          children_first_time: 2,
          children_ongoing: 5,
          teens_ongoing: 3,
        )

        @workshop_log2 = create(:workshop_log,
          workshop_id: @workshop2.id,
          project_id: @project.id,
          user_id: @user.id,
          date: 2.months.ago,
          adults_first_time: 2,
          adults_ongoing: 8,
          children_first_time: 1,
          children_ongoing: 3,
          teens_first_time: 1,
          teens_ongoing: 2,
        )

        sign_in @user
        visit "/workshop_logs?user_id=#{@user.id}"
      end

      it "verifies workshop log page has all required elements" do
        expect(page).to have_content("Workshop logs")
        expect(page).to have_content("Date")
        expect(page).to have_content("Workshop")
        expect(page).to have_content("Facilitator")
        expect(page).to have_content("# Ongoing")
        expect(page).to have_content("# First-time")
        expect(page).to have_content("children")
        expect(page).to have_content("teens")
        expect(page).to have_content("adults")
        expect(page).to have_content("Action")
        expect(page).to have_link("Edit")
        expect(page).to have_link("View")
      end

      it "displays all workshop logs with correct information" do
        expect(page).to have_content(@workshop_log1.date.strftime("%b %d, %Y"))
        expect(page).to have_content(@workshop1.title)
        expect(page).to have_content("#{@user.first_name} #{@user.last_name}")
        expect(page).to have_content("5")
        expect(page).to have_content("3")
        expect(page).to have_content("10")
        expect(page).to have_content("2")
        expect(page).to have_content("4")
        expect(page).to have_content("--")
        expect(page).to have_content("Grand Total:")

        expect(page).to have_content(@workshop_log2.date.strftime("%b %d, %Y"))
        expect(page).to have_content(@workshop2.title)
        expect(page).to have_content("#{@user.first_name} #{@user.last_name}")
      end

      it "filters workshop logs by month submitted" do
        expect(page).to have_content("Month Submitted")
        find("#month_and_year").click
        month_filter = @workshop_log2.date.strftime("%B %Y")
        select month_filter, from: "month_and_year"
        sleep 0.5
        expect(page).to have_content(@workshop_log2.date.strftime("%b %d, %Y"))
        expect(page).to have_content(@workshop2.title)
        expect(page).to have_content("#{@user.first_name} #{@user.last_name}")
        expect(page).not_to have_content(@workshop_log1.date.strftime("%b %d, %Y"))
        expect(page).not_to have_content(@workshop1.title)
      end
    end
  end
end
