require "rails_helper"

RSpec.describe "Dedupe preview autosave", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:keep) { create(:person, first_name: "Keep", last_name: "Person", email: "keeper@example.com", user: nil) }
  let!(:delete_rec) { create(:person, first_name: "Delete", last_name: "Person", email: "dropped@example.com", user: nil) }

  before { sign_in admin }

  it "says the field saved once the kept person's edit autosaves" do
    visit dedupe_preview_people_path(person_to_keep_id: keep.id, person_to_delete_id: delete_rec.id)

    find("input[name$='[email_2]']").set("dropped@example.com")
    page.execute_script("document.activeElement.blur()")

    expect(page).to have_css("[data-field-name='person_to_keep[email_2]']", text: "Saved")
    expect(keep.reload.email_2).to eq("dropped@example.com")
  end

  it "says why the field didn't save" do
    visit dedupe_preview_people_path(person_to_keep_id: keep.id, person_to_delete_id: delete_rec.id)

    find("input[name$='[email_2]']").set("not-an-email")
    page.execute_script("document.activeElement.blur()")

    expect(page).to have_css("[data-field-name='person_to_keep[email_2]']", text: "Not saved: Validation failed: Email 2 must be a valid email address")
  end
end
