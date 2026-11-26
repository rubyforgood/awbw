require "rails_helper"

RSpec.describe "Affiliation type selector", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, user: admin) }
  let(:organization) { create(:organization) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in admin
  end

  def hidden?(element)
    element[:class].split.include?("hidden")
  end

  it "stamps the selected role onto newly added rows" do
    visit edit_person_path(person)

    add_type = find("select[data-affiliation-add-type-target='select']")
    expect(add_type.value).to eq("job")

    click_link "Add Affiliation"
    expect(page).to have_css("#person_affiliation_rows_active .nested-fields", minimum: 1, wait: 5)
    job_row = all("#person_affiliation_rows_active .nested-fields").last
    expect(job_row.find("input[name*='[type]']", visible: :all).value).to eq("job")
    expect(job_row.find("input[name*='[title]']")).to be_visible

    add_type.select("Facilitator")
    before_count = all("#person_affiliation_rows_active .nested-fields").count
    click_link "Add Affiliation"
    expect(page).to have_css("#person_affiliation_rows_active .nested-fields", count: before_count + 1, wait: 5)
    facilitator_row = all("#person_affiliation_rows_active .nested-fields").last
    expect(facilitator_row.find("input[name*='[type]']", visible: :all).value).to eq("facilitator")
    expect(hidden?(facilitator_row.find("[data-inactive-toggle-target='titleField']", visible: :all))).to be(true)
    expect(hidden?(facilitator_row.find("[data-inactive-toggle-target='facilitatorLabel']", visible: :all))).to be(false)
  end

  it "shows a persisted facilitator's type read-only and changes it on the full editor" do
    affiliation = create(:affiliation, :facilitator, person: person, organization: organization)

    visit edit_affiliation_path(affiliation)

    type = find("select[name='affiliation[type]']")
    expect(type.value).to eq("facilitator")
    expect(hidden?(find("[data-inactive-toggle-target='titleField']", visible: :all))).to be(true)
    expect(hidden?(find("[data-inactive-toggle-target='facilitatorLabel']", visible: :all))).to be(false)

    type.select("Job")

    expect(hidden?(find("[data-inactive-toggle-target='titleField']", visible: :all))).to be(false)
    expect(hidden?(find("[data-inactive-toggle-target='facilitatorLabel']", visible: :all))).to be(true)
  end
end
