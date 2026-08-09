require "rails_helper"

RSpec.describe "Events attendees", type: :request do
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

  let(:frame_headers) { { "Turbo-Frame" => "attendees_results" } }
  # The charts are lazy-loaded into their own frame, only when the admin reveals them.
  let(:charts_frame_headers) { { "Turbo-Frame" => "attendees_charts" } }

  describe "GET /events/attendees" do
    context "as a user who owns no events" do
      it "redirects — there is nothing for them to report on" do
        sign_in user
        get attendees_events_url
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an event owner" do
      let(:owner) { create(:user) }
      let!(:owned_training) { create(:event, title: "Owned TAC", abbreviation: "OWN100", facilitator_training: true, created_by: owner, start_date: Date.new(2026, 6, 1)) }
      let!(:own_attendee) { create(:person, first_name: "Mine", last_name: "Own") }
      let!(:own_registration) { create(:event_registration, event: owned_training, registrant: own_attendee, status: "attended") }

      before { sign_in owner }

      it "renders the shell for an event they own" do
        get attendees_events_url(event_id: owned_training.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Event attendees")
        expect(response.body).to include(owned_training.decorate.compact_label)
      end

      it "returns the eyebrow to their event's dashboard" do
        get attendees_events_url(event_id: owned_training.id)
        expect(response.body).to include(dashboard_event_path(owned_training))
      end

      it "forbids an event they do not own" do
        get attendees_events_url(event_id: recent_training.id)
        expect(response).to redirect_to(root_path)
      end

      # Clearing the Training filter used to re-enter the admin-only cross-event
      # view and bounce the owner to root — inside a Turbo frame, a broken frame.
      it "renders the unfiltered view narrowed to their own events" do
        get attendees_events_url, headers: frame_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Mine Own")
        expect(response.body).not_to include("Ada Lovelace")
      end

      it "only offers their own trainings in the Training filter" do
        get attendees_events_url

        expect(response.body).to include("Owned TAC")
        expect(response.body).not_to include("TAC 261")
      end

      it "shows the empty state rather than an error when none of their events are trainings" do
        owned_training.update!(facilitator_training: false)

        get attendees_events_url, headers: frame_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No training attendees found.")
      end

      # An array event_id resolves to one event for authorization but would reach
      # a raw `where` as several. Whichever of the two authorize_report! lands on,
      # the policy scope keeps the other event's people out.
      it "never widens the roster when event_id is passed as an array" do
        get attendees_events_url(event_id: [ owned_training.id, recent_training.id ]), headers: frame_headers

        expect(response.body).not_to include("Ada Lovelace")
      end

      it "keeps another event's trainings out of a shared attendee's Training column" do
        create(:event_registration, event: recent_training, registrant: own_attendee, status: "attended")

        get attendees_events_url, headers: frame_headers
        expect(response.body).to include("OWN100")
        expect(response.body).not_to include("TAC261")
      end
    end

    context "as admin" do
      before { sign_in admin }

      it "renders the index shell" do
        get attendees_events_url
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Event attendees")
      end

      it "offers the program-status filter and keeps its selection" do
        get attendees_events_url(program_status: "reinstated")
        expect(response.body).to include("Program status")
        expect(Capybara.string(response.body))
          .to have_selector("select#program_status option[selected][value='reinstated']")
      end

      it "carries the participation origin back through the eyebrow" do
        get attendees_events_url(return_to: "participation")
        expect(response.body).to include("← Participation")
      end

      it "logs an Ahoy page-view event (once, not for the lazy frames)" do
        expect(Analytics::AhoyTracker).to receive(:track_event).with(anything, "view.events.attendees", {})
        get attendees_events_url
      end

      context "the results frame" do
        it "lists people who attended a training and links each to its registration" do
          get attendees_events_url, headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).to include("TAC261")
          expect(response.body).to include(edit_event_registration_path(attendee_registration))
        end

        it "excludes non-training attendees and no-shows" do
          get attendees_events_url, headers: frame_headers
          expect(response.body).not_to include("Grace Hopper")
          expect(response.body).not_to include("Alan Turing")
        end

        it "filters by training" do
          create(:event_registration, event: older_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get attendees_events_url(event_id: recent_training.id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Katherine Johnson")
        end

        it "filters by year" do
          create(:event_registration, event: older_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get attendees_events_url(event_year: 2024), headers: frame_headers
          expect(response.body).to include("Katherine Johnson")
          expect(response.body).not_to include("Ada Lovelace")
        end

        it "filters by name search" do
          create(:event_registration, event: recent_training, registrant: create(:person, first_name: "Katherine", last_name: "Johnson"), status: "attended")

          get attendees_events_url(contact_info: "Lovelace"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Katherine Johnson")
        end

        it "shows the Program status and Affiliation status columns" do
          get attendees_events_url, headers: frame_headers
          expect(response.body).to include("Program status")
          expect(response.body).to include("Affiliation status")
        end

        it "offers a charts toggle in the results frame but defers the charts to their lazy frame" do
          get attendees_events_url, headers: frame_headers
          expect(response.body).to include("Show charts")
          expect(response.body).to include("Hide table")
          # Charts are not rendered inline — they load into the lazy charts frame.
          # ("All sectors" is a breakdown-card title; the roster's own header says
          # "Primary sector", so that phrase isn't a reliable charts marker.)
          expect(response.body).not_to include("All sectors")
        end

        it "renders the breakdown charts in the lazy charts frame" do
          create(:sectorable_item, sectorable: attendee, sector: create(:sector, name: "Healthcare"), is_primary: true)
          get attendees_events_url, headers: charts_frame_headers
          expect(response.body).to include("Primary sector")
          expect(response.body).to include("All sectors")
        end

        it "filters by a breakdown drill-in (country)" do
          create(:address, addressable: attendee, country: "Canada", inactive: false)
          other = create(:person, first_name: "Zed", last_name: "Zulu")
          create(:event_registration, event: recent_training, registrant: other, status: "attended")

          get attendees_events_url(country: "Canada"), headers: frame_headers
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

          get attendees_events_url, headers: charts_frame_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("All cities")
          expect(response.body).to include("Austin, TX")

          get attendees_events_url(org_city: "Austin, TX"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Zed Zulu")
        end

        it "renders the cities charts when a city has scholarship recipients" do
          # The scholarship-only cities sub-table must use the index drill-in paths,
          # not the event-scoped registrant links (there is no @event on the index —
          # that raised a nil-event UrlGenerationError).
          org = create(:organization, name: "Wellness Org")
          create(:address, addressable: org, city: "Austin", state: "TX", inactive: false)
          attendee_registration.event_registration_organizations.create!(organization: org)
          award = create(:scholarship, recipient: attendee, amount_cents: 1_000, grant: create(:grant))
          create(:allocation, source: award, allocatable: attendee_registration, amount: 1_000)

          get attendees_events_url, headers: charts_frame_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("All cities")
        end

        it "filters by explicit registrant_ids (from the reports-hub totals)" do
          other = create(:person, first_name: "Zed", last_name: "Zulu")
          create(:event_registration, event: recent_training, registrant: other, status: "attended")

          get attendees_events_url(registrant_ids: attendee.id.to_s), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Zed Zulu")
        end

        it "filters by affiliation status" do
          create(:affiliation, person: attendee, organization: create(:organization), inactive: true, title: "Facilitator")
          active_person = create(:person, first_name: "Nora", last_name: "Active")
          create(:event_registration, event: recent_training, registrant: active_person, status: "attended")
          create(:affiliation, person: active_person, organization: create(:organization), start_date: 1.year.ago, inactive: false, title: "Facilitator")

          get attendees_events_url(affiliation_status: "Inactive"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Nora Active")
        end

        it "filters by the org's facilitator program status" do
          # Ada's org is new (no earlier facilitator affiliation); Zed's org is
          # ongoing (a facilitator affiliation predates and still overlaps today).
          new_org = create(:organization, name: "Fresh Org")
          attendee_registration.event_registration_organizations.create!(organization: new_org)

          ongoing = create(:person, first_name: "Zed", last_name: "Zulu")
          ongoing_registration = create(:event_registration, event: recent_training, registrant: ongoing, status: "attended")
          ongoing_org = create(:organization, name: "Established Org")
          create(:affiliation, organization: ongoing_org, start_date: 2.years.ago, inactive: false, title: "Facilitator")
          ongoing_registration.event_registration_organizations.create!(organization: ongoing_org)

          get attendees_events_url(program_status: "new"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Zed Zulu")
        end
      end
    end
  end
end
