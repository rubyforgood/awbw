require "rails_helper"

RSpec.describe "Events recipient shout-out form", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, start_date: 1.month.from_now, end_date: 1.month.from_now + 1.day) }
  let(:registration_form) { create(:form, name: "Registration") }
  let(:scholarship_form) { create(:form, :scholarship) }
  let(:applicant) { create(:person, first_name: "Tara", last_name: "Gallagher") }
  let!(:registration) do
    create(:event_registration, event: event, registrant: applicant, status: "registered", scholarship_requested: true)
  end

  before do
    create(:event_form, :registration, event: event, form: registration_form)
    create(:event_form, :scholarship, event: event, form: scholarship_form)
    sign_in admin
  end

  it "features the chosen recipient via Turbo and redirects to their registration edit form" do
    visit recipients_event_path(event)

    within("#shout-outs") do
      expect(page).to have_button("Add shoutout")
      # Select recipient via select_tag / TomSelect wrapper
      select applicant.name, from: "registration_id", visible: false
      click_button "Add shoutout"
    end

    expect(page).to have_current_path(
      edit_event_registration_path(registration, return_to: "recipients", anchor: "shout-out")
    )
    expect(page).to have_content("Featured on the recipients page — review their shout-out text below.")
    expect(registration.reload.shoutout).to be(true)
  end

  it "shows a warning alert when submitting without choosing a recipient" do
    visit recipients_event_path(event)

    within("#shout-outs") do
      click_button "Add shoutout"
    end

    expect(page).to have_current_path(recipients_event_path(event))
    expect(page).to have_content("Choose a recipient to feature.")
    expect(registration.reload.shoutout).to be(false)
  end

  it "disables the submit button while submission is in progress" do
    visit recipients_event_path(event)

    within("#shout-outs") do
      button = find("button[type='submit']")
      expect(button["data-turbo-submits-with"]).to eq("Adding…")
    end
  end
end
