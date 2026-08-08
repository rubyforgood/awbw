require "rails_helper"

RSpec.describe "Events training attendees", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  let!(:recent_training) { create(:event, title: "TAC 261", abbreviation: "TAC261", facilitator_training: true, start_date: Date.new(2026, 5, 1)) }
  let!(:older_training) { create(:event, title: "TAC 200", facilitator_training: true, start_date: Date.new(2024, 5, 1)) }
  let!(:webinar) { create(:event, title: "Open webinar", facilitator_training: false, start_date: Date.new(2025, 5, 1)) }

  let!(:attendee) { create(:person, first_name: "Ada", last_name: "Lovelace") }
  let!(:non_training_attendee) { create(:person, first_name: "Grace", last_name: "Hopper") }
  let!(:no_show) { create(:person, first_name: "Alan", last_name: "Turing") }

  let!(:attendee_registration) { create(:event_registration, event: recent_training, registrant: attendee, status: "attended") }

  before do
    create(:event_registration, event: webinar, registrant: non_training_attendee, status: "attended")
    create(:event_registration, event: recent_training, registrant: no_show, status: "no_show")
  end

  let(:frame_headers) { { "Turbo-Frame" => "training_attendees_results" } }

  describe "GET /events/training_attendees" do
    context "as non-admin" do
      it "redirects" do
        sign_in user
        get training_attendees_events_url
        expect(response).to redirect_to(root_path)
      end
    end

    context "as admin" do
      before { sign_in admin }

      it "renders the index shell" do
        get training_attendees_events_url
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Training attendees")
      end

      it "carries the participation origin back through the eyebrow" do
        get training_attendees_events_url(return_to: "participation")
        expect(response.body).to include("← Participation")
      end

      context "the results frame" do
        it "lists people who attended a training and links each to its registration" do
          get training_attendees_events_url, headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).to include("TAC261")
          expect(response.body).to include(edit_event_registration_path(attendee_registration))
        end

        it "excludes non-training attendees and no-shows" do
          get training_attendees_events_url, headers: frame_headers
          expect(response.body).not_to include("Grace Hopper")
          expect(response.body).not_to include("Alan Turing")
        end

        it "filters by training" do
          create(:event_registration, event: older_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get training_attendees_events_url(event_id: recent_training.id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Katherine Johnson")
        end

        it "filters by year" do
          create(:event_registration, event: older_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get training_attendees_events_url(event_year: 2024), headers: frame_headers
          expect(response.body).to include("Katherine Johnson")
          expect(response.body).not_to include("Ada Lovelace")
        end

        it "filters by name search" do
          create(:event_registration, event: recent_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get training_attendees_events_url(contact_info: "Lovelace"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Katherine Johnson")
        end

        it "shows the Program status and Affiliation status columns" do
          get training_attendees_events_url, headers: frame_headers
          expect(response.body).to include("Program status")
          expect(response.body).to include("Affiliation status")
        end

        it "renders the breakdown charts in the results frame" do
          create(:sectorable_item, sectorable: attendee, sector: create(:sector, name: "Healthcare"), is_primary: true)
          get training_attendees_events_url, headers: frame_headers
          expect(response.body).to include("Primary sector")
          expect(response.body).to include("All sectors")
        end

        it "filters by a breakdown drill-in (country)" do
          create(:address, addressable: attendee, country: "Canada", inactive: false)
          other = create(:person, first_name: "Zed", last_name: "Zulu")
          create(:event_registration, event: recent_training, registrant: other, status: "attended")

          get training_attendees_events_url(country: "Canada"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Zed Zulu")
        end

        it "renders the cities breakdown and filters by an org-city drill-in" do
          org = create(:organization, name: "Wellness Org")
          create(:address, addressable: org, city: "Austin", state: "TX", inactive: false)
          attendee_registration.event_registration_organizations.create!(organization: org)

          other = create(:person, first_name: "Zed", last_name: "Zulu")
          other_registration = create(:event_registration, event: recent_training, registrant: other, status: "attended")
          other_org = create(:organization, name: "Other Org")
          create(:address, addressable: other_org, city: "Reno", state: "NV", inactive: false)
          other_registration.event_registration_organizations.create!(organization: other_org)

          # An org with no address falls into the non-clickable "Unknown" bucket —
          # this used to raise a UrlGenerationError (nil event) on the index.
          cityless = create(:person, first_name: "Nora", last_name: "Nowhere")
          cityless_registration = create(:event_registration, event: recent_training, registrant: cityless, status: "attended")
          cityless_registration.event_registration_organizations.create!(organization: create(:organization, name: "Cityless Org"))

          get training_attendees_events_url, headers: frame_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("All cities")
          expect(response.body).to include("Austin, TX")

          get training_attendees_events_url(org_city: "Austin, TX"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Zed Zulu")
        end

        it "filters by affiliation status" do
          create(:affiliation, person: attendee, organization: create(:organization), inactive: true, title: "Facilitator")
          active_person = create(:person, first_name: "Nora", last_name: "Active")
          create(:event_registration, event: recent_training, registrant: active_person, status: "attended")
          create(:affiliation, person: active_person, organization: create(:organization), start_date: 1.year.ago, inactive: false, title: "Facilitator")

          get training_attendees_events_url(affiliation_status: "Inactive"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Nora Active")
        end
      end
    end
  end
end
