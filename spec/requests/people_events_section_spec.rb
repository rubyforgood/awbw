require "rails_helper"

RSpec.describe "Person profile events section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_events_section
    get person_path(person, section: "events"),
        headers: { "Turbo-Frame" => "person_events_section" }
  end

  def registration_for(event_title, status:)
    event = create(:event, title: event_title)
    create(:event_registration, registrant: person, event: event, status: status)
  end

  it "shows an active registration without a status badge" do
    registration_for("Active Event", status: "registered")

    get_events_section

    expect(response).to be_successful
    expect(response.body).to include("Active Event")
    expect(response.body).not_to include("No show")
  end

  it "shows a reconciled-away registration to an admin, flagged with its status" do
    registration_for("Missed Event", status: "no_show")

    get_events_section

    expect(response.body).to include("Missed Event")
    expect(response.body).to include("No show")
    expect(response.body).to include("bg-blue-50")
  end

  it "flags a cancelled registration with its status for an admin" do
    registration_for("Dropped Event", status: "cancelled")

    get_events_section

    expect(response.body).to include("Dropped Event")
    expect(response.body).to include("Cancelled")
  end

  it "still shows the reconciled-away registration, flagged, to the owner viewing their own profile" do
    sign_in owner_user
    registration_for("Missed Event", status: "no_show")

    get_events_section

    expect(response.body).to include("Missed Event")
    expect(response.body).to include("No show")
  end
end
