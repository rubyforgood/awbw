require "rails_helper"

RSpec.describe "Organization profile events-attended section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_events_section
    get organization_path(organization, section: "events"),
        headers: { "Turbo-Frame" => "organization_events_section" }
  end

  # A registration is linked to the organization the registrant submitted on the
  # form (or that an admin connected), which is what surfaces the event on the
  # organization profile.
  def register(event:, status: "registered")
    person = create(:person)
    create(:affiliation, organization: organization, person: person)
    registration = create(:event_registration, registrant: person, event: event, status: status)
    registration.event_registration_organizations.create!(organization: organization)
    registration
  end

  it "shows events members are actively registered for" do
    event = create(:event, title: "Trauma-Informed Art Day")
    register(event: event)

    get_events_section

    expect(response).to be_successful
    expect(response.body).to include("Trauma-Informed Art Day")
  end

  it "excludes cancelled and no-show registrations" do
    cancelled = create(:event, title: "Cancelled Workshop")
    no_show = create(:event, title: "Missed Workshop")
    register(event: cancelled, status: "cancelled")
    register(event: no_show, status: "no_show")

    get_events_section

    expect(response.body).not_to include("Cancelled Workshop")
    expect(response.body).not_to include("Missed Workshop")
    expect(response.body).to include("No events recorded.")
  end

  it "lists each event once even when several members attended it" do
    event = create(:event, title: "Shared Event")
    register(event: event)
    register(event: event)

    get_events_section

    # One card, not one per registration (the title renders as a ">Shared Event" node).
    expect(response.body.scan(/>\s*Shared Event/).size).to eq(1)
  end

  it "shows an admin program-status chip per event in the profile's Program status block" do
    event = create(:event, title: "Trauma-Informed Onsite", abbreviation: "TOS205", start_date: 2.days.from_now, facilitator_training: true)
    person = create(:person)
    create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: 1.year.ago, end_date: nil)
    registration = create(:event_registration, registrant: person, event: event, status: "registered")
    registration.event_registration_organizations.create!(organization: organization)

    get organization_path(organization)

    expect(response.body).to include("Program status")
    expect(response.body).to include("TOS205")
    expect(response.body).to include("Ongoing")
    # The chip opens in a new tab, so it must tell the report how to get back here —
    # and the block needs the id the report's eyebrow anchors to.
    expect(response.body).to include(
      CGI.escapeHTML(participation_events_path(event_id: event.id, organization_id: organization.id, return_to: "organization"))
    )
    expect(response.body).to include("id=\"#{EventParticipationHelper::PROGRAM_STATUS_ANCHOR}\"")
  end

  it "renders the section heading and lazy frame on the profile page" do
    get organization_path(organization)

    expect(response.body).to include("Events attended")
    expect(response.body).to include("organization_events_section")
  end
end
