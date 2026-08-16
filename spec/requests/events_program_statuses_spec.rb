require "rails_helper"

# The annual-reporting page: organizations by program status at each facilitator
# training, with year totals. See ADR-0001 D4/D8.
RSpec.describe "Events program-status report", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:training) do
    create(:event, title: "Trauma-Informed Onsite", abbreviation: "TOS205",
                   facilitator_training: true, start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 3, 2))
  end
  let!(:established) { create(:organization, name: "Established Program") }

  def represent(organization, event)
    registration = create(:event_registration, event: event, registrant: create(:person), status: "registered")
    registration.event_registration_organizations.create!(organization: organization)
  end

  before do
    create(:affiliation, organization: established, person: create(:person),
                         title: "Facilitator", start_date: Date.new(2019, 5, 1))
    represent(established, training)
    sign_in admin
  end

  it "lists each training with its organizations split by status on the training's date" do
    get program_statuses_events_path

    expect(response).to be_successful
    expect(response.body).to include("TOS205")
    # The date every verdict in the row was judged on.
    expect(response.body).to include("Mar 1, 2026")
    expect(response.body).to include("Distinct organizations")
  end

  it "excludes events that aren't facilitator trainings" do
    social = create(:event, title: "Zibberpicnic Social", facilitator_training: false, start_date: Date.new(2026, 4, 1))
    represent(established, social)

    get program_statuses_events_path

    # Only the report card — the event filter's select lists every event by name.
    report = Capybara.string(response.body).find("#program-status-report")
    expect(report).to have_text("TOS205")
    expect(report).to have_no_text("Zibberpicnic")
  end

  it "is reachable from the reports hub" do
    get reports_events_path

    expect(response.body).to include("Program status")
    expect(response.body).to include(program_statuses_events_path)
  end

  it "is refused to a signed-out visitor" do
    sign_out admin

    get program_statuses_events_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
