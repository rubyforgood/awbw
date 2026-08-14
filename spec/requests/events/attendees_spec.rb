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
        expect(response.body).to include("No attendees found.")
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

      it "surfaces an applied drill-in filter as a removable chip" do
        get attendees_events_url(country: "Canada", state: "OR")
        # The chip labels the applied filter and its ✕ links back to the index
        # with only that param dropped (the other filters are preserved).
        expect(response.body).to include("Country: Canada")
        expect(Capybara.string(response.body))
          .to have_link(href: attendees_events_path(state: "OR"))
      end

      # payment_status and funder narrow the population but have no select here —
      # without a chip they'd shrink the list silently, and without the hidden
      # field the next select change would drop them.
      it "chips the money drill-ins and carries them through the filter form" do
        get attendees_events_url(payment_status: "unpaid", funder: "external")

        expect(response.body).to include("Payment: Due")
        expect(response.body).to include("Funding: Grant-funded")
        page = Capybara.string(response.body)
        expect(page).to have_selector("input[type=hidden][name=payment_status][value=unpaid]", visible: :all)
        expect(page).to have_selector("input[type=hidden][name=funder][value=external]", visible: :all)
        expect(page).to have_link(href: attendees_events_path(funder: "external"))
      end

      it "does not show the applied-filters row when only visible filters are set" do
        get attendees_events_url(state: "OR")
        expect(response.body).not_to include(">Applied<")
      end

      it "carries the participation origin back through the eyebrow" do
        get attendees_events_url(return_to: "participation")
        expect(response.body).to include("← Event participation")
      end

      it "returns to the revenue report when a money KPI drilled in" do
        get attendees_events_url(return_to: "revenue", payment_status: "unpaid")
        expect(response.body).to include("← Event revenue")
      end

      # A report KPI passes both return_to and event_id; the explicit origin has to
      # win, or the back link drops the user on the event dashboard instead of the
      # report they were reading.
      it "prefers the report origin over the event fallback" do
        get attendees_events_url(return_to: "participation", event_id: recent_training.id)

        expect(response.body).to include("← Event participation")
        expect(response.body).to include(CGI.escapeHTML(participation_events_path(event_id: recent_training.id)))
        expect(response.body).not_to include("← #{recent_training.title}")
      end

      it "logs an Ahoy page-view event (once, not for the lazy frames)" do
        expect(Analytics::AhoyTracker).to receive(:track_event).with(anything, "view.events.attendees", {})
        get attendees_events_url
      end

      # The population is defaults, not a fixed base — so the page can also answer
      # "no shows" and "non-trainings" for the report KPIs that drill in here.
      context "the population filters" do
        it "defaults to attended registrations on trainings" do
          get attendees_events_url, headers: frame_headers

          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Alan Turing")
          expect(response.body).not_to include("Grace Hopper")
        end

        it "reaches no-shows, which the old fixed population excluded outright" do
          get attendees_events_url(attendance_status: "no_show"), headers: frame_headers

          expect(response.body).to include("Alan Turing")
          expect(response.body).not_to include("Ada Lovelace")
        end

        it "reaches non-training events" do
          get attendees_events_url(event_type: "other"), headers: frame_headers

          expect(response.body).to include("Grace Hopper")
          expect(response.body).not_to include("Ada Lovelace")
        end

        # The reports hub forwards its Event type value straight through, so the
        # delivery-format splits have to narrow here too — otherwise picking Live
        # or On-demand on a report would widen the drill-in to every event type.
        context "with the delivery-format splits the report filter offers" do
          let!(:on_demand_training) { create(:event, title: "TAC on demand", facilitator_training: true, on_demand: true, start_date: Date.new(2026, 4, 1)) }
          let!(:on_demand_attendee) { create(:person, first_name: "Katherine", last_name: "Johnson") }

          before { create(:event_registration, event: on_demand_training, registrant: on_demand_attendee, status: "attended") }

          it "narrows to live trainings" do
            get attendees_events_url(event_type: "live"), headers: frame_headers

            expect(response.body).to include("Ada Lovelace")
            expect(response.body).not_to include("Katherine Johnson")
            expect(response.body).not_to include("Grace Hopper")
          end

          it "narrows to on-demand trainings" do
            get attendees_events_url(event_type: "on_demand"), headers: frame_headers

            expect(response.body).to include("Katherine Johnson")
            expect(response.body).not_to include("Ada Lovelace")
            expect(response.body).not_to include("Grace Hopper")
          end
        end

        it "drops both narrowings for the all-outcomes drill-in" do
          get attendees_events_url(attendance_status: EventRegistration::FILTER_ALL,
                                   event_type: EventRegistration::FILTER_ALL), headers: frame_headers

          expect(response.body).to include("Ada Lovelace", "Alan Turing", "Grace Hopper")
        end

        it "shows the resolved population in the subtitle so the defaults aren't hidden" do
          get attendees_events_url
          expect(response.body).to include("Attended · All trainings")

          get attendees_events_url(attendance_status: "no_show")
          expect(response.body).to include("No show · All trainings")
        end

        it "pre-selects the defaults in the filter form rather than a blank All" do
          get attendees_events_url
          page = Capybara.string(response.body)

          expect(page).to have_selector("select#attendance_status option[selected][value='attended']")
          expect(page).to have_selector("select#event_type option[selected][value='trainings']")
        end
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

        it "offers a breakdowns toggle in the results frame but defers the charts to their lazy frame" do
          get attendees_events_url, headers: frame_headers
          expect(response.body).to include("Show breakdowns")
          expect(response.body).to include("Hide attendees")
          # Charts are not rendered inline — they load into the lazy charts frame.
          # ("All sectors" is a breakdown-card title; the roster's own header says
          # "Primary sector", so that phrase isn't a reliable charts marker.)
          expect(response.body).not_to include("All sectors")
        end

        # The heading lands in the DOM only once the results frame resolves, long
        # after the browser gave up on the #breakdowns fragment — so it has to scroll
        # itself into view on connect rather than rely on the hash.
        it "anchors the breakdowns heading so a #breakdowns link still scrolls to it" do
          get attendees_events_url, headers: frame_headers

          expect(Capybara.string(response.body))
            .to have_selector("#breakdowns[data-controller='reveal-section'][data-reveal-section-anchor-value='breakdowns']", visible: :all)
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

        it "filters by the combined Active & Upcoming status" do
          create(:affiliation, person: attendee, organization: create(:organization), inactive: true, title: "Facilitator")
          active_person = create(:person, first_name: "Nora", last_name: "Active")
          create(:event_registration, event: recent_training, registrant: active_person, status: "attended")
          create(:affiliation, person: active_person, organization: create(:organization), start_date: 1.year.ago, inactive: false, title: "Facilitator")
          upcoming_person = create(:person, first_name: "Uma", last_name: "Upcoming")
          create(:event_registration, event: recent_training, registrant: upcoming_person, status: "attended")
          create(:affiliation, person: upcoming_person, organization: create(:organization), start_date: 1.month.from_now, inactive: false, title: "Facilitator")

          get attendees_events_url(affiliation_status: Affiliation::ACTIVE_OR_UPCOMING), headers: frame_headers
          expect(response.body).to include("Nora Active")
          expect(response.body).to include("Uma Upcoming")
          expect(response.body).not_to include("Ada Lovelace")
        end

        it "offers the combined option in the filter and keeps its selection" do
          get attendees_events_url(affiliation_status: Affiliation::ACTIVE_OR_UPCOMING)

          expect(Capybara.string(response.body))
            .to have_selector("select#affiliation_status option[selected]", text: "Active & Upcoming")
        end

        it "filters by scholarship status, including the recipient sub-statuses" do
          complete = create(:scholarship, recipient: attendee, amount_cents: 1_000, grant: create(:grant), tasks_completed: true)
          create(:allocation, source: complete, allocatable: attendee_registration, amount: 1_000)

          incomplete_person = create(:person, first_name: "Ivy", last_name: "Incomplete")
          incomplete_reg = create(:event_registration, event: recent_training, registrant: incomplete_person, status: "attended")
          incomplete = create(:scholarship, recipient: incomplete_person, amount_cents: 1_000, grant: create(:grant), tasks_completed: false)
          create(:allocation, source: incomplete, allocatable: incomplete_reg, amount: 1_000)

          no_award = create(:person, first_name: "Nell", last_name: "Nograant")
          create(:event_registration, event: recent_training, registrant: no_award, status: "attended")

          get attendees_events_url(scholarship: "yes"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace", "Ivy Incomplete")
          expect(response.body).not_to include("Nell Nograant")

          get attendees_events_url(scholarship: "complete"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Ivy Incomplete", "Nell Nograant")

          get attendees_events_url(scholarship: "no"), headers: frame_headers
          expect(response.body).to include("Nell Nograant")
          expect(response.body).not_to include("Ada Lovelace", "Ivy Incomplete")
        end

        it "answers 'No scholarship' per event when scoped, but person-wide cross-event" do
          # Ada is a recipient at the recent training but holds no scholarship at the
          # older one she also attended.
          award = create(:scholarship, recipient: attendee, amount_cents: 1_000, grant: create(:grant))
          create(:allocation, source: award, allocatable: attendee_registration, amount: 1_000)
          create(:event_registration, event: older_training, registrant: attendee, status: "attended")

          never = create(:person, first_name: "Nora", last_name: "Never")
          create(:event_registration, event: recent_training, registrant: never, status: "attended")

          # Cross-event: "No scholarship" means never a recipient — excludes Ada.
          get attendees_events_url(scholarship: "no"), headers: frame_headers
          expect(response.body).to include("Nora Never")
          expect(response.body).not_to include("Ada Lovelace")

          # Scoped to the older training, where Ada holds no scholarship — includes her.
          get attendees_events_url(scholarship: "no", event_id: older_training.id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
        end

        it "answers 'No comments' person-wide cross-event, per event when scoped" do
          # Ada commented on her recent-training registration but not on the older
          # training she also attended.
          create(:comment, commentable: attendee_registration)
          older_reg = create(:event_registration, event: older_training, registrant: attendee, status: "attended")

          quiet = create(:person, first_name: "Quinn", last_name: "Quiet")
          create(:event_registration, event: recent_training, registrant: quiet, status: "attended")

          # Cross-event: "None" means commented on nothing — excludes Ada, whose
          # older-training registration is uncommented.
          get attendees_events_url(comment_status: "none"), headers: frame_headers
          expect(response.body).to include("Quinn Quiet")
          expect(response.body).not_to include("Ada Lovelace")

          # Scoped to the older training, where Ada's registration carries no
          # comment — includes her.
          get attendees_events_url(comment_status: "none", event_id: older_reg.event_id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
        end

        it "answers 'No CE' person-wide cross-event, per event when scoped" do
          # Ada took CE at the recent training but not at the older one she also
          # attended.
          create(:continuing_education_registration, event_registration: attendee_registration)
          older_reg = create(:event_registration, event: older_training, registrant: attendee, status: "attended")

          never = create(:person, first_name: "Nan", last_name: "Nocredit")
          create(:event_registration, event: recent_training, registrant: never, status: "attended")

          # Cross-event: "No CE" means never signed up — excludes Ada, whose
          # older-training registration carries no CE.
          get attendees_events_url(ce_status: "none"), headers: frame_headers
          expect(response.body).to include("Nan Nocredit")
          expect(response.body).not_to include("Ada Lovelace")

          # Scoped to the older training, where Ada took no CE — includes her.
          get attendees_events_url(ce_status: "none", event_id: older_reg.event_id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
        end

        it "filters by address data (city) without requiring a registration to carry it" do
          create(:address, addressable: attendee, city: "Portland", state: "OR", inactive: false)
          other = create(:person, first_name: "Cara", last_name: "Coast")
          create(:event_registration, event: recent_training, registrant: other, status: "attended")
          create(:address, addressable: other, city: "Seattle", state: "WA", inactive: false)

          get attendees_events_url(city: "portland"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Cara Coast")
        end

        it "filters by an active topic subscription, matching any of the person's registrations" do
          type = create(:topic_subscription_type)
          create(:topic_subscription, person: attendee, topic_subscription_type: type)
          unsubbed = create(:person, first_name: "Uma", last_name: "Unsub")
          create(:event_registration, event: recent_training, registrant: unsubbed, status: "attended")
          create(:topic_subscription, :unsubscribed, person: unsubbed, topic_subscription_type: type)

          get attendees_events_url(topic_subscription: type.id), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Uma Unsub")
        end

        it "filters by a registration-level attribute (CE status) across events" do
          # Ada has a CE registration at the older training; the filter should surface
          # her on the cross-event index even though her recent-training reg has none.
          older_reg = create(:event_registration, event: older_training, registrant: attendee, status: "attended")
          create(:continuing_education_registration, event_registration: older_reg)
          plain = create(:person, first_name: "Cy", last_name: "Noce")
          create(:event_registration, event: recent_training, registrant: plain, status: "attended")

          get attendees_events_url(ce_status: "registered"), headers: frame_headers
          expect(response.body).to include("Ada Lovelace")
          expect(response.body).not_to include("Cy Noce")
        end

        it "always offers the scholarship filter and keeps its selection" do
          get attendees_events_url(scholarship: "complete")
          expect(response.body).to include("Scholarship")
          expect(Capybara.string(response.body))
            .to have_selector("select#scholarship option[selected][value='complete']", text: "Tasks complete")
        end

        # A param the index narrows on but the form doesn't render would shrink the
        # list silently and then be dropped by the form's next auto-submit, since
        # only rendered fields and the CHIP_PARAMS hidden inputs are sent.
        it "renders a control for every registration-level filter it honours" do
          topic = create(:topic_subscription_type)
          get attendees_events_url

          page = Capybara.string(response.body)
          EventsController::ATTENDEE_REGISTRATION_FILTERS.each_key do |param|
            expect(page).to have_selector("##{param}", visible: :all), "no control for #{param}"
          end
          expect(page).to have_selector("#city", visible: :all)
          expect(page).to have_selector("#topic_subscription option[value='#{topic.id}']", visible: :all)
        end

        it "keeps the registration-level filter selections" do
          get attendees_events_url(ce_status: "issued", city: "Portland", comment: "late")

          page = Capybara.string(response.body)
          expect(page).to have_selector("select#ce_status option[selected][value='issued']", text: "Certificate issued")
          expect(page).to have_selector("input#city[value='Portland']", visible: :all)
          expect(page).to have_selector("input#comment[value='late']", visible: :all)
        end

        # The form posts into the results frame, and the frame's own links (the
        # charts frame, its drill-ins) are built from that request's params — so
        # return_to has to survive a filter change or the eyebrow loses its origin.
        it "carries return_to through the filter form" do
          get attendees_events_url(return_to: "participation")

          expect(Capybara.string(response.body))
            .to have_selector("input[type=hidden][name=return_to][value=participation]", visible: :all)
        end

        # The chip row lives outside the results frame, so its remove links would
        # otherwise keep pointing at the params the page loaded with — dropping every
        # filter the admin set through the frame since.
        it "refreshes the applied-filter chips from the results frame" do
          get attendees_events_url(country: "Canada", ce_status: "issued"), headers: frame_headers

          # Turbo stream payloads sit inside a <template>, which selectors don't
          # descend into — read the replacement's markup out first.
          template = Nokogiri::HTML5(response.body)
            .at_css("turbo-stream[action='replace'][target='attendees_chips'] template")
          expect(template).to be_present

          remove_link = "a[aria-label='Remove Country: Canada filter']"
          expect(Capybara.string(template.inner_html)).to have_selector(
            "#{remove_link}[href='#{attendees_events_path(ce_status: "issued")}']", visible: :all
          )
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
