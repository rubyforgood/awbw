require "rails_helper"

# The standalone affiliation editor reuses inactive-toggle, the same live styling
# the nested rows on the person/organization editors use.
RSpec.describe "Affiliation editor live styling", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, user: admin) }
  let!(:organization) { create(:organization) }
  let!(:affiliation) do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 2.years.ago.to_date)
  end

  before do
    driven_by(:selenium_chrome_headless)
    sign_in admin
    visit edit_affiliation_path(affiliation)
  end

  def row = find("[data-inactive-toggle-target='row']")

  # The controller ends a row on the *browser's* today, while Ruby's Date.current
  # follows the Rails zone — they disagree for part of each day. Ask the browser.
  def browser_today
    page.evaluate_script(
      "(() => { const d = new Date(); const p = n => String(n).padStart(2, '0'); " \
      "return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}` })()"
    )
  end

  def set_end_date(value)
    page.execute_script(
      "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', { bubbles: true }))",
      find("[data-inactive-toggle-target~='endDate']"), value
    )
  end


  it "tints an active facilitator row without striking it through" do
    expect(row[:class]).to include("bg-purple-50")
    expect(row[:class]).not_to include("aff-ended")
  end

  it "strikes the row through as soon as the Inactive box is ticked" do
    find("[data-inactive-toggle-target='inactiveCheckbox']").click

    expect(row[:class]).to include("aff-ended")
  end

  it "strikes it through for an end date of today, which the date rule alone calls active" do
    set_end_date(browser_today)

    expect(row[:class]).to include("aff-ended")
  end

  def checkbox = find("[data-inactive-toggle-target='inactiveCheckbox']")

  describe "the Inactive checkbox following the end date" do
    it "ticks itself for a past end date, so the flag submits with the form" do
      expect(checkbox).not_to be_checked

      set_end_date(1.month.ago.to_date.strftime("%Y-%m-%d"))

      expect(checkbox).to be_checked
    end

    it "ticks itself for an end date of today, which the date rule alone calls active" do
      set_end_date(browser_today)

      expect(checkbox).to be_checked
    end

    it "unticks itself for a future end date" do
      set_end_date(1.month.ago.to_date.strftime("%Y-%m-%d"))
      expect(checkbox).to be_checked

      set_end_date(1.year.from_now.to_date.strftime("%Y-%m-%d"))

      expect(checkbox).not_to be_checked
    end

    it "unticks itself when the end date is cleared" do
      set_end_date(1.month.ago.to_date.strftime("%Y-%m-%d"))

      set_end_date("")

      expect(checkbox).not_to be_checked
    end

    # The point of the whole mechanism: the flag has to survive the round trip.
    it "persists inactive after saving an end date of today" do
      set_end_date(browser_today)
      click_button "Save changes"

      expect(page).to have_text("successfully updated")
      expect(affiliation.reload.inactive).to be(true)
      expect(affiliation).not_to be_active
    end

    # Only the end date drives the box; a hand tick with no end date must stick.
    it "leaves a hand-ticked box alone" do
      checkbox.click

      expect(checkbox).to be_checked
      expect(row[:class]).to include("aff-ended")
    end
  end

  it "switches the hue when the title stops being Facilitator" do
    title = find("[data-inactive-toggle-target~='title']")
    page.execute_script(
      "arguments[0].value = 'Counselor'; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))",
      title
    )

    expect(row[:class]).to include("bg-blue-50")
  end
end
