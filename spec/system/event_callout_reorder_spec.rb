require "rails_helper"

RSpec.describe "Reordering ticket callouts on the event edit form", type: :system, js: true do
  let(:admin) { create(:user, :with_person, :admin) }
  let(:event) { create(:event) }

  before do
    driven_by(:selenium_chrome_headless)
    BuiltinCallouts.seed(event)
  end

  # fields_for emits a hidden id input after each callout row inside the sortable
  # list; the position sent must count only the callout rows, not those inputs.
  it "saves the dragged callout at the slot it was dropped in" do
    ordered = event.registration_ticket_callouts.ordered.to_a
    moved = ordered[4]
    target = ordered[1]

    sign_in(admin)
    visit edit_event_path(event)
    click_button id: "registration_ticket_callouts_button"

    handle = find("#registration_ticket_callouts_list > [data-sortable-id='#{moved.id}'] [data-sortable-handle]")
    drop = find("#registration_ticket_callouts_list > [data-sortable-id='#{target.id}']")
    handle.drag_to(drop, html5: true)

    # The saved order must match the order the admin sees after the drop.
    expected = all("#registration_ticket_callouts_list > [data-sortable-id]").map { |row| row["data-sortable-id"].to_i }
    expect(expected).not_to eq(ordered.map(&:id))
    10.times do
      break if event.registration_ticket_callouts.reload.ordered.map(&:id) == expected
      sleep 0.2
    end
    expect(event.registration_ticket_callouts.reload.ordered.map(&:id)).to eq(expected)
  end
end
