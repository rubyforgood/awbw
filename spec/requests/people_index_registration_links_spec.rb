require "rails_helper"

RSpec.describe "People index registration quick-links", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }

  before { sign_in admin }

  it "links the latest training registration" do
    person = create(:person, first_name: "Trainee")
    training = create(:event, title: "TAC261", facilitator_training: true, start_date: 6.months.ago)
    registration = create(:event_registration, registrant: person, event: training)

    get people_path, headers: turbo_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("TAC261 reg")
    expect(response.body).to include(event_registration_path(registration))
  end

  it "links registrations for events from a month ago into the future" do
    person = create(:person, first_name: "Attendee")
    upcoming = create(:event, title: "Upcoming Fest", start_date: 10.days.from_now)
    recent = create(:event, title: "Recent Fest", start_date: 2.weeks.ago)
    reg_upcoming = create(:event_registration, registrant: person, event: upcoming)
    reg_recent = create(:event_registration, registrant: person, event: recent)

    get people_path, headers: turbo_headers

    expect(response.body).to include("Upcoming Fest reg")
    expect(response.body).to include("Recent Fest reg")
    expect(response.body).to include(event_registration_path(reg_upcoming))
    expect(response.body).to include(event_registration_path(reg_recent))
  end

  it "omits registrations for events older than a month that aren't the latest training" do
    person = create(:person, first_name: "Old")
    old_event = create(:event, title: "Ancient Fest", start_date: 3.months.ago)
    create(:event_registration, registrant: person, event: old_event)

    get people_path, headers: turbo_headers

    expect(response.body).not_to include("Ancient Fest reg")
  end

  it "breaks registration links out of the results frame" do
    person = create(:person)
    event = create(:event, title: "Frame Fest", start_date: 5.days.from_now)
    registration = create(:event_registration, registrant: person, event: event)

    get people_path, headers: turbo_headers

    expect_frame_breakout(response.body, event_registration_path(registration))
  end
end
