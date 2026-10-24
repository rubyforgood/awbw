require "rails_helper"

RSpec.describe "Index note hint", type: :system, js: true do
  let(:admin) { create(:user, :admin, :with_person) }
  let!(:tagging) { create(:staff_tagging) }

  before { sign_in admin }

  it "shows the editor's initials as soon as the note autosaves" do
    visit staff_taggings_path

    hint = "##{ActionView::RecordIdentifier.dom_id(tagging, :note_hint)}"
    within("turbo-frame#staff_taggings_results") do
      expect(page).to have_css(hint, text: "", exact_text: true)
      fill_in "note", with: "Called them"
      page.execute_script("document.activeElement.blur()")
    end

    expect(page).to have_css(hint, text: admin.decorate.initials)
    expect(page).to have_css("[data-field-name='note']", text: "Saved")
    expect(tagging.comments.sole.body).to eq("Called them")
  end
end
