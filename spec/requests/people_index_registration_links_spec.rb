require "rails_helper"

RSpec.describe "People index registration quick-links", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }

  before { sign_in admin }

  it "falls back to the latest training when none is in the recent/upcoming window" do
    person = create(:person, first_name: "Trainee")
    training = create(:event, title: "TAC261", facilitator_training: true, start_date: 6.months.ago)
    registration = create(:event_registration, registrant: person, event: training)

    get people_path, headers: turbo_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("TAC261")
    expect(response.body).to include(event_registration_path(registration))
  end

  it "drops the old-training fallback when a training already falls in the window" do
    person = create(:person, first_name: "Trainee")
    old_training = create(:event, title: "OldTAC", facilitator_training: true,
                                   start_date: 8.months.ago, end_date: 8.months.ago + 1.day)
    upcoming_training = create(:event, title: "NewTAC", facilitator_training: true,
                                       start_date: 3.weeks.from_now, end_date: 3.weeks.from_now + 1.day)
    create(:event_registration, registrant: person, event: old_training)
    create(:event_registration, registrant: person, event: upcoming_training)

    get people_path, headers: turbo_headers

    expect(response.body).to include("NewTAC")
    expect(response.body).not_to include("OldTAC")
  end

  it "links registrations for events from a month ago into the future" do
    person = create(:person, first_name: "Attendee")
    upcoming = create(:event, title: "Upcoming Fest", start_date: 10.days.from_now)
    recent = create(:event, title: "Recent Fest", start_date: 2.weeks.ago)
    reg_upcoming = create(:event_registration, registrant: person, event: upcoming)
    reg_recent = create(:event_registration, registrant: person, event: recent)

    get people_path, headers: turbo_headers

    expect(response.body).to include("Upcoming Fest")
    expect(response.body).to include("Recent Fest")
    expect(response.body).to include(event_registration_path(reg_upcoming))
    expect(response.body).to include(event_registration_path(reg_recent))
  end

  it "omits non-training registrations for events older than a month" do
    person = create(:person, first_name: "Old")
    old_event = create(:event, title: "Ancient Fest", start_date: 3.months.ago)
    create(:event_registration, registrant: person, event: old_event)

    get people_path, headers: turbo_headers

    expect(response.body).not_to include("Ancient Fest")
  end

  it "breaks registration links out of the results frame" do
    person = create(:person)
    event = create(:event, title: "Frame Fest", start_date: 5.days.from_now)
    registration = create(:event_registration, registrant: person, event: event)

    get people_path, headers: turbo_headers

    expect_frame_breakout(response.body, event_registration_path(registration))
  end
end
