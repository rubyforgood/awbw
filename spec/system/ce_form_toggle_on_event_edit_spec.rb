require "rails_helper"

RSpec.describe "CE form toggle on event edit", type: :system do
  let(:admin) { create(:user, :with_person, :admin) }
  let(:event) { create(:event) }
  let(:ce_form) { create(:form, role: "continuing_education", name: "CE Request") }

  before do
    ce_form # ensure the form exists so controller populates @continuing_education_forms
    sign_in admin
  end

  context "when CE form is not attached" do
    it "keeps the enable checkbox in Form settings and collapses the CE settings section" do
      visit edit_event_path(event)
      expect(page).to have_unchecked_field("event[continuing_education_form_id]")
      expect(page).to have_text("Set hours, cost, deadlines, and timesheets in the Continuing education section below.")
      expect(page).to have_field("event[ce_hours_offered]", visible: :hidden)

      click_button "Continuing education"
      expect(page).to have_field("event[ce_hours_offered]")
      expect(page).to have_field("event[ce_payment_due_deadline_date]")
      expect(page).to have_checked_field("Use CE timesheets")
      expect(page).to have_select("Timesheet opens for editing")
      expect(page).to have_field("event[ce_timesheet_closes_at_date]")
    end
  end

  context "when CE form is attached" do
    before do
      create(:event_form, event: event, form: ce_form, role: "continuing_education")
      visit edit_event_path(event)
    end

    it "shows hours/cost fields" do
      expect(page).to have_checked_field("event[continuing_education_form_id]")
      expect(page).to have_field("event[ce_hours_offered]", visible: :visible)
    end

    it "shows the timesheet controls" do
      expect(page).to have_checked_field("Use CE timesheets")
      expect(page).to have_select("Timesheet opens for editing", selected: "As soon as CE is paid")
      expect(page).to have_field("event[ce_timesheet_closes_at_date]")
    end
  end
end
