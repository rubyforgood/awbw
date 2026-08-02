require "rails_helper"

# The dashboard groups its breakdown cards into rows of native <details>. Opening
# or closing one card should mirror onto the rest of that row (details-row-sync
# controller).
RSpec.describe "Event dashboard details row sync", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, :published, cost: 25) }

  before { sign_in admin }

  it "opens and closes every card in a row together" do
    visit dashboard_event_path(event)

    # The headcount row (Registrants / Organizations / Sectors / States) always
    # renders regardless of the event's data. Grab it via a card unique to it.
    sectors_card = find("details.group\\/card", text: "Sectors")
    row = sectors_card.find(:xpath, "..")
    card_count = row.all("details.group\\/card", minimum: 2).size

    # All start collapsed.
    expect(row).to have_no_css("details.group\\/card[open]")

    sectors_card.find("summary").click
    expect(row).to have_css("details.group\\/card[open]", count: card_count, wait: 5)

    sectors_card.find("summary").click
    expect(row).to have_no_css("details.group\\/card[open]", wait: 5)
  end
end
