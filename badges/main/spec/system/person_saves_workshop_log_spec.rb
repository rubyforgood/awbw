require "rails_helper"

RSpec.describe "Saving a workshop log", type: :system do
  def select_tom_select_option(hidden_select_id, value, label)
    page.execute_script(<<~JS)
      var el = document.getElementById('#{hidden_select_id}');
      var ts = el.tomselect;
      ts.addOption({id: '#{value}', label: '#{label}'});
      ts.setValue('#{value}');
    JS
  end

  shared_context "workshop log form setup" do
    let(:windows_type) { create(:windows_type, :combined) }
    let!(:form_builder) do
      fb = FormBuilder.create!(windows_type_id: windows_type.id, name: "Combined form")
      fb.forms.create!
      fb
    end
    let!(:workshop) do
      create(:workshop, :published, title: "Healing Through Art", windows_type: windows_type)
    end
    let(:organization) do
      create(:organization, name: "Community Arts Project", windows_type_id: windows_type.id)
    end

    def fill_and_submit_workshop_log
      visit new_workshop_log_path

      expect(page).to have_content("New workshop log")

      # Select workshop via TomSelect
      select_tom_select_option("workshop_log_workshop_id", workshop.id, workshop.title)

      # Fill in workshop date (JS to reliably set HTML5 date input)
      page.execute_script(
        "document.getElementById('workshop_log_workshop_held_on').value = '#{1.day.ago.strftime('%Y-%m-%d')}'"
      )

      # Fill in participant counts
      fill_in "workshop_log_children_ongoing", with: "3"
      fill_in "workshop_log_teens_ongoing", with: "2"
      fill_in "workshop_log_adults_ongoing", with: "8"
      fill_in "workshop_log_children_first_time", with: "1"
      fill_in "workshop_log_teens_first_time", with: "0"
      fill_in "workshop_log[adults_first_time]", with: "5"

      click_button "Submit"
    end
  end

  describe "as a regular user" do
    include_context "workshop log form setup"

    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }

    before do
      create(:affiliation, person: person, organization: organization)
      sign_in user
    end

    it "successfully saves a workshop log" do
      fill_and_submit_workshop_log

      expect(page).to have_content("Thank you for submitting a workshop log")
      expect(WorkshopLog.count).to eq(1)

      log = WorkshopLog.last
      expect(log.workshop).to eq(workshop)
      expect(log.organization).to eq(organization)
      expect(log.created_by).to eq(user)
      expect(log.children_ongoing).to eq(3)
      expect(log.teens_ongoing).to eq(2)
      expect(log.adults_ongoing).to eq(8)
      expect(log.children_first_time).to eq(1)
      expect(log.teens_first_time).to eq(0)
      expect(log.adults_first_time).to eq(5)
      expect(log.total_attendance).to eq(19)
    end
  end

  describe "as an admin" do
    include_context "workshop log form setup"

    let(:admin) { create(:user, :admin) }
    let(:person) { create(:person, user: admin) }

    before do
      create(:affiliation, person: person, organization: organization)
      sign_in admin
    end

    it "successfully saves a workshop log" do
      fill_and_submit_workshop_log

      expect(page).to have_content("Thank you for submitting a workshop log")
      expect(WorkshopLog.count).to eq(1)

      log = WorkshopLog.last
      expect(log.workshop).to eq(workshop)
      expect(log.organization).to eq(organization)
      expect(log.created_by).to eq(admin)
      expect(log.children_ongoing).to eq(3)
      expect(log.adults_first_time).to eq(5)
      expect(log.total_attendance).to eq(19)
    end
  end
end
