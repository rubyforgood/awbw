require "rails_helper"

RSpec.describe "Event attendees index", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:training) { create(:event, title: "TAC 261", facilitator_training: true, start_date: 1.month.ago) }
  let!(:attendee) { create(:person, first_name: "Ada", last_name: "Lovelace") }
  let!(:registration) { create(:event_registration, event: training, registrant: attendee, status: "attended") }

  before { sign_in admin }

  # The Breakdowns heading arrives inside the lazily-loaded results frame, long
  # after the browser gave up on the hash, so it scrolls itself into view on
  # connect. Turbo frame submits never touch the address bar, so the hash has to be
  # dropped once it's been honoured — otherwise every later filter change would
  # re-render the heading and yank the page back to it.
  scenario "Admin lands on the breakdowns section and the hash stops pulling them back" do
    visit attendees_events_path(charts: 1, anchor: "breakdowns")

    expect(page).to have_css("#breakdowns")
    expect(page).to have_current_path(%r{/events/attendees\?charts=1\z}, url: true)
  end
end
