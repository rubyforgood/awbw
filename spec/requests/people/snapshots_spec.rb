require "rails_helper"

RSpec.describe "Person snapshots", type: :request do
  let(:person) do
    create(:person, first_name: "Jordan", last_name: "Sample", email: "jordan.sample@example.com").tap do |record|
      create(:affiliation, person: record, organization: create(:organization, name: "Harbor House"),
             type: "facilitator", start_date: 1.year.ago, inactive: false)
    end
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "renders the snapshot sections" do
      event = create(:event, title: "Facilitator Training", facilitator_training: true,
                     start_date: Date.new(2025, 6, 4), end_date: Date.new(2025, 6, 6))
      registration = create(:event_registration, registrant: person, event: event, status: "attended")
      registration.organizations << create(:organization, name: "Lakeside Center")
      membership = create(:membership, person: person, start_date: Date.current,
                           end_date: Date.current + 1.year)

      get person_snapshot_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jordan Sample")
      expect(response.body).to include("Harbor House")
      expect(response.body).to include("Facilitator Training")
      expect(response.body).to include(membership.decorate.period_label)
      expect(response.body).to include(">Affiliated since #{1.year.ago.strftime("%b %Y")}</h2>")
      expect(response.body).not_to include(">Affiliations</h2>")
      expect(response.body).to include(">Facilitator trainings</h2>")
      expect(response.body).to match(/\d{4} · Lakeside Center</)
      expect(response.body).to include(">Membership</h2>")
    end

    it "shortens incomplete attendance" do
      event = create(:event, facilitator_training: true)
      create(:event_registration, registrant: person, event:, status: "incomplete_attendance")

      get person_snapshot_path(person)

      expect(response.body).to include("<span>Incomplete</span>")
      expect(response.body).not_to include("Incomplete attendance")
    end

    it "shows the empty state when there is nothing to snapshot" do
      empty_person = create(:person, first_name: "Empty", last_name: "Snapshot")

      get person_snapshot_path(empty_person)

      expect(response.body).to include("No snapshot content yet.")
      expect(response.body).not_to include(">Affiliations</h2>")
      expect(response.body).not_to include(">Facilitator trainings</h2>")
      expect(response.body).not_to include(">Membership</h2>")
    end

    it "shows the affiliated since heading when every affiliation has ended" do
      former = create(:person)
      create(:affiliation, person: former, organization: create(:organization),
             start_date: Date.new(2020, 3, 1), end_date: Date.new(2021, 1, 1))

      get person_snapshot_path(former)

      expect(response.body).to include(">Affiliated since Mar 2020</h2>")
      expect(response.body).to include("No snapshot content yet.")
    end

    it "leaves the status pill blank for a JA-only org" do
      staffer = create(:person)
      create(:affiliation, person: staffer, organization: create(:organization, name: "Riverbend Shelter"),
             title: "Program Director", start_date: 1.year.ago, inactive: false)

      get person_snapshot_path(staffer)

      expect(response.body).to include("Riverbend Shelter", "Program Director")
      expect(response.body).not_to include("fa-circle-check")
    end

    it "answers a turbo stream request by filling the snapshot mount with the dialog" do
      get person_snapshot_path(person), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="modal_mount">')
      expect(response.body).to include("<dialog")
      expect(response.body).to include("Jordan Sample")
      expect(response.body).to include(edit_person_path(person))
      expect(response.body).to include(comments_and_communications_path(person_id: person.id))
    end

    it "renders the snapshot trigger beside the person card on the people index" do
      person
      get people_path, headers: { "Turbo-Frame" => "people_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person_snapshot_path(person))
      expect(response.body).to include("Snapshot for Jordan Sample")
    end
  end

  context "as a non-admin" do
    before { sign_in create(:user, :with_person) }

    it "redirects away instead of rendering the snapshot" do
      get person_snapshot_path(person)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("not authorized")
    end
  end
end
