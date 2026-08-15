require 'rails_helper'

RSpec.describe "organizations/edit", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:organization_status) { create(:organization_status) }
  let(:windows_type) { create(:windows_type) }

  let(:organization) {
    Organization.create!(
      windows_type: windows_type,
      organization_status: organization_status,
      location: nil,
      name: "MyString",
      description: "MyString",
      notes: "MyText"
    )
  }

  before(:each) do
    assign(:organization, organization)
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
  end

  it "renders the edit organization form" do
    render
    assert_select "form[action=?][method=?]", organization_path(organization), "post" do
      assert_select "select[name=?]", "organization[windows_type_id]"

      assert_select "textarea[name=?]", "organization[name]"

      assert_select "textarea[name=?]", "organization[description]"
    end
  end

  describe "status select visibility" do
    before(:each) { assign(:organization_statuses, OrganizationStatus.all) }

    def org_with_status(name)
      Organization.create!(
        windows_type: windows_type,
        organization_status: OrganizationStatus.find_or_create_by!(name: name),
        name: "MyString",
        description: "MyString",
        notes: "MyText"
      )
    end

    it "hides the status select without the admin param" do
      assign(:organization, org_with_status("Active"))
      render
      assert_select "select[name=?]", "organization[organization_status_id]", false
      assert_select "input[type=hidden][name=?]", "organization[organization_status_id]"
    end

    it "shows the status select with the admin param" do
      allow(view).to receive(:params).and_return(ActionController::Parameters.new(admin: "true"))
      assign(:organization, org_with_status("Active"))
      render
      assert_select "select[name=?]", "organization[organization_status_id]"
    end

    it "shows a warning icon (not the select) when the stored status does not match the affiliation status" do
      org = org_with_status("Pending")
      create(:affiliation, organization: org, person: create(:person), inactive: false, end_date: nil)
      assign(:organization, org.reload)
      render
      assert_select "select[name=?]", "organization[organization_status_id]", false
      assert_select "i.fa-triangle-exclamation"
      expect(rendered).to include("Legacy organization status does not match affiliation status")
    end

    it "shows no warning icon when the stored status matches the affiliation status" do
      org = org_with_status("Active")
      create(:affiliation, organization: org, person: create(:person), inactive: false, end_date: nil)
      assign(:organization, org.reload)
      render
      expect(rendered).not_to include("Legacy organization status does not match affiliation status")
    end

    # The mismatch is judged on program-status buckets, so a stored status that
    # buckets the same way as the affiliations is not a mismatch, whatever its name.
    it "warns when a stored 'Active' org has affiliations but none are facilitators" do
      org = org_with_status("Active")
      create(:affiliation, organization: org, person: create(:person), title: "Volunteer", inactive: false, end_date: nil)
      assign(:organization, org.reload)
      render
      expect(rendered).to include("Legacy organization status does not match affiliation status")
    end

    it "shows no warning icon for a stored 'Pending' org with no facilitator affiliations" do
      assign(:organization, org_with_status("Pending"))
      render
      expect(rendered).not_to include("Legacy organization status does not match affiliation status")
    end

    it "shows no warning icon for stored 'Reinstate' with an active facilitator (both active)" do
      org = org_with_status("Reinstate")
      create(:affiliation, organization: org, person: create(:person), inactive: false, end_date: nil)
      assign(:organization, org.reload)
      render
      expect(rendered).not_to include("Legacy organization status does not match affiliation status")
    end

    it "shows no warning icon for stored 'Suspended' with only lapsed facilitators (both formerly active)" do
      org = org_with_status("Suspended")
      create(:affiliation, organization: org, person: create(:person),
                           start_date: 3.years.ago.to_date, end_date: 1.year.ago.to_date)
      assign(:organization, org.reload)
      render
      expect(rendered).not_to include("Legacy organization status does not match affiliation status")
    end
  end

  describe "art program since" do
    before(:each) { assign(:organization_statuses, OrganizationStatus.all) }

    around { |ex| travel_to(Date.new(2026, 8, 3)) { ex.run } }

    it "shows the earliest facilitator start (month precision), not the latest, wired for live updates" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Active"))
      create(:affiliation, organization: org, person: create(:person), title: "Facilitator",
                           start_date: Date.new(2025, 8, 1), end_date: nil)
      create(:affiliation, organization: org, person: create(:person), title: "Facilitator",
                           start_date: Date.new(2026, 9, 1), end_date: nil)
      assign(:organization, org.reload)
      render

      assert_select "[data-affiliation-dates-target='facilitatorSince']", text: /Aug 2025/
      assert_select "[data-affiliation-dates-target='facilitatorSince']", text: /Sep 2026/, count: 0
    end

    # This form and the profile used to render "Art program since" two different
    # ways — the profile as merged periods, this form as one earliest→latest span,
    # which silently swallowed the gap. Both now render the one decorator value.
    it "renders a lapse and a return as separate periods, matching the profile" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Active"))
      create(:affiliation, organization: org, person: create(:person), title: "Facilitator",
                           start_date: Date.new(2015, 8, 1), end_date: Date.new(2018, 6, 1))
      create(:affiliation, organization: org, person: create(:person), title: "Facilitator",
                           start_date: Date.new(2024, 2, 1), end_date: nil)
      assign(:organization, org.reload)
      render

      expect(org.reload.decorate.program_since_display).to eq("Aug 2015 – Jun 2018, Feb 2024")
      assert_select "[data-affiliation-dates-target='facilitatorSince']",
                    text: org.decorate.program_since_display
    end
  end

  describe "program status" do
    it "renders a 'date · status · event' chip for each event the org is represented at" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Active"))
      person = create(:person)
      create(:affiliation, organization: org, person: person, title: "Facilitator",
                           start_date: Date.new(2020, 1, 1), end_date: nil)
      event = create(:event, title: "August Training", abbreviation: "PES205", start_date: Date.new(2026, 8, 1))

      assign(:organization, org.reload)
      assign(:organization_statuses, OrganizationStatus.all)
      assign(:organization_events, Event.where(id: event.id))
      render

      expect(rendered).to include("Aug 2026 · Ongoing · PES205")
      # Opens in a new tab, so the report needs the route back to this form —
      # and the block needs the id that back-link anchors to.
      expect(rendered).to include(CGI.escapeHTML(
        participation_events_path(event_id: event.id, return_organization_id: org.id, return_to: "organization_edit")
      ))
      expect(rendered).to include("id=\"#{EventParticipationHelper::PROGRAM_STATUS_ANCHOR}\"")
    end

    it "always shows the general status chip, even with no events" do
      org = organization
      org.update!(organization_status: OrganizationStatus.find_or_create_by!(name: "Unknown"))
      assign(:organization, org.reload)
      assign(:organization_statuses, OrganizationStatus.all)
      assign(:organization_events, Event.none)
      render

      assert_select "label", text: /Program status/
      expect(rendered).to include("Never active")
    end
  end

  describe "new affiliation defaults" do
    it "defaults the start date to today and leaves primary contact unchecked" do
      organization.affiliations.build
      render
      assert_select "input[name*='start_date'][value=?]",
                    Date.current.strftime("%Y-%m-%d")
      assert_select "input[type=checkbox][name*='primary_contact']"
      assert_select "input[type=checkbox][name*='primary_contact'][checked]", false
    end
  end
end
