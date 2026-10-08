require "rails_helper"

# The searchable-checkbox controller hands the select to TomSelect, which takes
# its prompt from the markup — a plain `placeholder` attribute (form submissions)
# or `data-placeholder` (the filter_multiselect partial). Both must survive the
# enhancement, so the control isn't a blank box before anything is picked.
RSpec.describe "Searchable multiselect placeholder", type: :system, js: true do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "keeps a placeholder-attribute prompt on the form submissions filter" do
    create(:form, name: "Volunteer interest")

    visit form_submissions_path

    expect(page).to have_css(".ts-wrapper input[placeholder='All forms']")
  end

  it "keeps a data-placeholder prompt on the people filters" do
    create(:topic_subscription_type, name: "News")

    visit people_path

    expect(page).to have_css(".ts-wrapper input[placeholder='Any topic']")
  end
end
