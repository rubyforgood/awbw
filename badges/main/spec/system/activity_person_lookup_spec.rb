require "rails_helper"

RSpec.describe "Activity person lookup", type: :system, js: true do
  let(:admin) { create(:user, super_user: true) }
  let!(:person) { create(:person, first_name: "Lookup", last_name: "Target") }

  before { sign_in admin }

  it "searches people remotely and opens the picked person's activity" do
    visit admin_activities_events_path

    expect(page).to have_css(".ts-control input[placeholder='e.g. Jane Doe']")
    expect(page).to have_no_css(".remote-select-icon")
    lookup_size = page.evaluate_script("getComputedStyle(document.querySelector('.ts-control input')).fontSize")
    neighbor_size = page.evaluate_script("getComputedStyle(document.querySelector('#event_name'), '::placeholder').fontSize")
    expect(lookup_size).to eq(neighbor_size)

    find(".ts-control").click
    find(".ts-control input").send_keys("Lookup")
    find(".ts-dropdown .option", text: "Lookup Target").click

    expect(page).to have_css("h1", text: "Lookup Target's activity")
    expect(page).to have_current_path(/person_id=#{person.id}/)
  end
end
