require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  # Makes the event CE-eligible (offers a positive number of CE hours), which
  # gates every CE column/filter/export.
  def offer_ce!(target_event)
    target_event.update!(ce_hours_offered: 6)
    target_event
  end

  let(:valid_params) do
    {
      event: {
        title: "Sample title",
        description: "Sample description",
        start_date: 1.day.from_now,
        end_date: 2.days.from_now,
        registration_close_date: 3.days.ago,
        published: true
      }
    }
  end

  let(:invalid_params) do
    { event: { title: "" } }
  end

  describe "GET /index" do
    it "is successful for signed in user" do
      sign_in user
      get events_path
      expect(response).to have_http_status(:ok)
    end

    context "when user time_zone is set" do
      # 19:00 UTC = 12:00 noon PT = 15:00 (3 pm) ET (June 15, 2031 with DST)
      let(:utc_start) { Time.utc(2031, 6, 15, 19, 0, 0) }
      let(:utc_end)   { Time.utc(2031, 6, 15, 20, 0, 0) }
      let!(:event_with_fixed_times) do
        create(:event, :published,
          start_date: utc_start,
          end_date: utc_end,
          title: "Timezone test event")
      end

      it "displays start time in Pacific (PT) for user with time_zone PT" do
        user_pt = create(:user)
        sign_in user_pt
        get event_url(event_with_fixed_times)
        expect(response).to be_successful
        # 19:00 UTC = 12:00 noon PT (styled format on show page)
        expect(response.body).to include("June 15, 2031")
        expect(response.body).to include("12 pm - 1 pm")
      end

      it "displays start time in Eastern for user with time_zone America/New_York" do
        user_et = create(:user, time_zone: "Eastern Time (US & Canada)")
        sign_in user_et
        get event_url(event_with_fixed_times)

        expect(response).to be_successful
        # 19:00 UTC = 3:00 pm ET (styled format on show page)
        expect(response.body).to include("June 15, 2031")
        expect(response.body).to include("3 pm - 4 pm")
      end
    end
  end

  describe "GET /show" do
    context "when event has ended" do
      let(:ended_event) { create(:event, :published, :ended) }

      it "allows admin to view" do
        sign_in admin
        get event_path(ended_event)
        expect(response).to have_http_status(:ok)
      end

      it "allows registered user to view" do
        user_with_person = create(:user, :with_person)
        sign_in user_with_person
        create(:event_registration, event: ended_event, registrant: user_with_person.person, status: "registered")
        get event_path(ended_event)
        expect(response).to have_http_status(:ok)
      end

      it "redirects unregistered user" do
        sign_in user
        get event_path(ended_event)
        expect(response).to redirect_to(root_path)
      end

      it "redirects unauthenticated user" do
        get event_path(ended_event)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /revenue" do
    let!(:paid_training) { create(:event, title: "TAC 261", facilitator_training: true, cost_cents: 10_000, start_date: Date.new(2026, 5, 1)) }
    let!(:paid_webinar) { create(:event, title: "Paid webinar", facilitator_training: false, cost_cents: 5_000, start_date: Date.new(2025, 5, 1)) }
    let!(:older_training) { create(:event, title: "TAC 200", facilitator_training: true, cost_cents: 8_000, start_date: Date.new(2024, 5, 1)) }
    let!(:free_event) { create(:event, title: "Free open house", cost_cents: 0) }

    context "as admin" do
      it "lists every paid event grouped by year, with the chart" do
        sign_in admin
        get revenue_events_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Event revenue")
        expect(response.body).to include("Revenue by year")
        expect(response.body).to include("Fees collected")
        expect(response.body).to include("TAC 261")
        expect(response.body).to include("Paid webinar")
        expect(response.body).to include("2026", "2025", "2024")
        expect(response.body).not_to include("Free open house")
      end

      it "returns to the originating event's dashboard when arrived from it" do
        sign_in admin
        get revenue_events_path(return_to: "dashboard", event_id: paid_training.id)
        expect(response.body).to include(dashboard_event_path(paid_training))
        expect(response.body).to include("← Dashboard")
      end
    end

    context "as non-admin" do
      it "redirects" do
        sign_in user
        get revenue_events_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /sample_ticket" do
    context "as admin" do
      before { sign_in admin }

      it "renders a preview ticket for an unsaved sample registration" do
        create(:registration_ticket_callout, event: event)
        get sample_ticket_event_path(event)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sample ticket preview")
        expect(response.body).to include("Sample Registrant")
        # Magic callout cards render (the sample event is paid, so the "Forms"
        # card shows) without raising on the unsaved sample's sentinel slug.
        expect(response.body).to include("Forms")
      end

      it "models a typical registrant by default, hiding scholarship and CE" do
        get sample_ticket_event_path(event)
        expect(response.body).not_to include("Your scholarship request status")
        expect(response.body).not_to include("CE hours")
        expect(response.body).to include("Show all options")
      end

      it "turns on every option with ?options=all" do
        get sample_ticket_event_path(event, options: "all")
        expect(response.body).to include("Your scholarship request status")
        expect(response.body).to include("CE hours")
        expect(response.body).to include("Show typical ticket")
      end

      it "does not create a registration" do
        expect { get sample_ticket_event_path(event) }
          .not_to change(EventRegistration, :count)
      end
    end

    context "as non-admin" do
      it "redirects" do
        sign_in user
        get sample_ticket_event_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /details" do
    let(:event) { create(:event, :published, :publicly_visible) }

    it "renders the details page when details are present" do
      event.update!(event_details_label: "Art supplies", event_details: "<p>Bring scissors</p>")
      get details_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Art supplies")
      expect(response.body).to include("Bring scissors")
    end

    it "redirects to the event when details are blank" do
      get details_event_path(event)
      expect(response).to redirect_to(event_path(event))
    end
  end

  describe "GET /ce_hours" do
    let(:event) { create(:event, :published, :publicly_visible) }

    it "renders the CE hours page when details are present" do
      event.update!(ce_hours_details_label: "Continuing education", ce_hours_details: "<p>Email your license number</p>")
      get ce_hours_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Continuing education")
      expect(response.body).to include("Email your license number")
    end

    it "redirects to the event when details are blank" do
      get ce_hours_event_path(event)
      expect(response).to redirect_to(event_path(event))
    end
  end

  describe "GET /new" do
    context "as admin" do
      it "renders successfully" do
        sign_in admin
        get new_event_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as non-admin" do
      it "redirects" do
        sign_in user
        get new_event_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /edit registration form section" do
    let(:event) { create(:event) }

    before { sign_in admin }

    it "shows preview links for enabled add-ons" do
      create(:event_form, event: event, form: create(:form, :standalone, role: "scholarship", name: "Scholarship"), role: "scholarship")
      create(:event_form, event: event, form: create(:form, :standalone, role: "bulk_payment", name: "Bulk"), role: "bulk_payment")
      get edit_event_path(event)
      expect(response.body).to include("Preview scholarship form")
      expect(response.body).to include("scholarship_requested=true")
      expect(response.body).to include("Preview bulk payment page")
      expect(response.body).to include("/events/#{event.id}/bulk_payment/new")
    end

    it "omits preview links when add-ons are disabled" do
      get edit_event_path(event)
      expect(response.body).not_to include("Preview scholarship form")
      expect(response.body).not_to include("Preview bulk payment page")
    end

    it "renders the built-in 'Before you attend' card fields within the callouts section" do
      get edit_event_path(event)
      expect(response.body).to include("Registration ticket callouts")
      expect(response.body).to include("Before you attend")
      expect(response.body).to include("event[event_details_label]")
      expect(response.body).to include("event[event_details]")
    end

    it "renders the built-in 'CE hours' card fields within the callouts section" do
      get edit_event_path(event)
      expect(response.body).to include("Registration ticket callouts")
      expect(response.body).to include("CE hours")
      expect(response.body).to include("event[ce_hours_details_label]")
      expect(response.body).to include("event[ce_hours_details]")
    end

    it "previews the app-controlled built-in callouts (greyed, non-editable)" do
      get edit_event_path(event)
      expect(response.body).to include("Frequently asked questions")
    end
  end

  describe "POST /create" do
    context "as admin" do
      before { sign_in admin }

      it "creates event" do
        expect {
          post events_path, params: valid_params
        }.to change(Event, :count).by(1)
      end

      it "redirects to the created event" do
        post events_path, params: valid_params
        expect(response).to redirect_to(event_url(Event.last))
      end

      it "stores start_date/end_date in UTC when created by user in Pacific time zone" do
        admin_pt = create(:user, :admin, time_zone: "Pacific Time (US & Canada)")
        sign_in admin_pt
        # date+time inputs send separate values — interpreted in request's Time.zone (PT)
        # 12:00–13:00 PT (PDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "PT event",
          description: "desc",
          start_date_date: "2025-06-15",
          start_date_time: "12:00",
          end_date_date: "2025-06-15",
          end_date_time: "13:00",
          registration_close_date: 1.day.ago,
          public: true
        } }

        created = Event.order(created_at: :desc).first
        expect(response).to redirect_to(event_url(created))
        expect(created.start_date.utc).to eq(Time.utc(2025, 6, 15, 19, 0, 0))
        expect(created.end_date.utc).to eq(Time.utc(2025, 6, 15, 20, 0, 0))
      end

      it "stores start_date/end_date in UTC when created by user in Eastern time zone" do
        admin_et = create(:user, :admin, time_zone: "Eastern Time (US & Canada)")
        sign_in admin_et
        # 15:00–16:00 ET (EDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "ET event",
          description: "desc",
          start_date_date: "2025-06-15",
          start_date_time: "15:00",
          end_date_date: "2025-06-15",
          end_date_time: "16:00",
          registration_close_date: 1.day.ago,
          public: true
        } }

        created = Event.order(created_at: :desc).first
        expect(response).to redirect_to(event_url(created))
        expect(created.start_date.utc).to eq(Time.utc(2025, 6, 15, 19, 0, 0))
        expect(created.end_date.utc).to eq(Time.utc(2025, 6, 15, 20, 0, 0))
      end
    end

    context "as non-admin" do
      before { sign_in user }

      it "does not create event" do
        expect {
          post events_path, params: valid_params
        }.not_to change(Event, :count)
      end

      it "redirects" do
        post events_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end

    context "when validation fails" do
      before { sign_in admin }

      it "re-renders the registration form selections the admin had chosen" do
        reg_form = create(:form, :standalone, role: "registration", name: "Custom Registration")
        scholarship_form = create(:form, :standalone, role: "scholarship")
        bulk_payment_form = create(:form, :standalone, role: "bulk_payment")

        post events_path, params: { event: {
          title: "Missing dates",
          start_date_date: "",
          start_date_time: "",
          end_date_date: "",
          end_date_time: "",
          registration_form_id: reg_form.id,
          scholarship_form_id: scholarship_form.id,
          bulk_payment_form_id: bulk_payment_form.id
        } }

        expect(response).to have_http_status(:unprocessable_content)
        page = Capybara.string(response.body)
        expect(page).to have_field("event[scholarship_form_id]", checked: true)
        expect(page).to have_field("event[bulk_payment_form_id]", checked: true)
        expect(response.body).to include("value=\"#{reg_form.id}\" selected")
      end

      it "retains selected sector and category checkboxes" do
        sector = create(:sector, :published)
        category = create(:category, :published, category_type: create(:category_type, :published))

        post events_path, params: { event: {
          title: "Missing dates",
          start_date_date: "",
          start_date_time: "",
          end_date_date: "",
          end_date_time: "",
          sector_ids: [ "", sector.id.to_s ],
          category_ids: [ "", category.id.to_s ]
        } }

        expect(response).to have_http_status(:unprocessable_content)
        page = Capybara.string(response.body)
        expect(page).to have_checked_field("event_sector_ids_#{sector.id}")
        expect(page).to have_checked_field("event_category_ids_#{category.id}")
      end
    end
  end

  describe "PATCH /update" do
    let(:update_params) { { event: { title: "Updated" } } }

    context "as admin" do
      before { sign_in admin }

      it "updates event" do
        patch event_path(event), params: update_params
        expect(event.reload.title).to eq("Updated")
      end

      it "redirects to the event dashboard" do
        patch event_path(event), params: update_params
        expect(response).to redirect_to(dashboard_event_path(event))
      end

      it "persists the show-details-on-registration toggle" do
        event.update!(autoshow_registration_details: false)
        patch event_path(event), params: { event: { autoshow_registration_details: "1" } }
        expect(event.reload.autoshow_registration_details).to be(true)
      end

      it "persists the facilitator training flag" do
        patch event_path(event), params: { event: { facilitator_training: "1" } }
        expect(event.reload.facilitator_training).to be(true)
      end

      it "persists the registration detail hints" do
        patch event_path(event), params: { event: {
          hint_dates: "must attend both days",
          hint_registration_cost: "due within 3 weeks of registration"
        } }
        expect(event.reload.hint_dates).to eq("must attend both days")
        expect(event.hint_registration_cost).to eq("due within 3 weeks of registration")
      end
    end

    context "as non-admin" do
      before { sign_in user }

      it "does not update" do
        patch event_path(event), params: update_params
        expect(event.reload.title).not_to eq("Updated")
      end

      it "redirects" do
        patch event_path(event), params: update_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /preview" do
    context "as admin" do
      before { sign_in admin }

      it "renders the show template with preview changes" do
        patch preview_event_path(event), params: { event: { title: "Preview Title" } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Preview Title")
        expect(response.body).to include("Preview")
      end

      it "does not persist changes to the database" do
        original_title = event.title
        patch preview_event_path(event), params: { event: { title: "Preview Title" } }
        expect(event.reload.title).to eq(original_title)
      end
    end

    context "as non-admin non-owner" do
      before { sign_in user }

      it "redirects" do
        patch preview_event_path(event), params: { event: { title: "Preview Title" } }
        expect(response).to redirect_to(root_path)
      end
    end

    context "as owner" do
      let(:owned_event) { create(:event, created_by: user) }

      before { sign_in user }

      it "renders the show template" do
        patch preview_event_path(owned_event), params: { event: { title: "Owner Preview" } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Owner Preview")
      end
    end
  end

  describe "DELETE /destroy" do
    context "as admin" do
      before { sign_in admin }

      it "destroys event" do
        event
        expect {
          delete event_path(event)
        }.to change(Event, :count).by(-1)
      end

      context "when the event has form submissions" do
        before { create(:form_submission, :with_event, event: event) }

        it "does not destroy the event" do
          event
          expect {
            delete event_path(event)
          }.not_to change(Event, :count)
        end

        it "redirects back to the event with an alert" do
          delete event_path(event)

          expect(response).to redirect_to(event_path(event))
          follow_redirect!
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "as non-admin" do
      before { sign_in user }

      it "does not destroy" do
        event
        expect {
          delete event_path(event)
        }.not_to change(Event, :count)
      end
    end
  end

  describe "GET /events/:id/registrants" do
    let(:person) { create(:person) }
    let!(:registration) { create(:event_registration, event: event, registrant: person) }

    before { sign_in admin }

    context "with unknown filter params" do
      it "does not crash on an invalid payment_status" do
        get registrants_event_path(event, payment_status: "bogus")

        expect(response).to have_http_status(:ok)
      end

      it "does not crash on an invalid scholarship status" do
        get registrants_event_path(event, scholarship: "bogus")

        expect(response).to have_http_status(:ok)
      end
    end

    context "active/inactive filtering" do
      let(:active_person) { create(:person, first_name: "Activa", last_name: "Attendee") }
      let(:inactive_person) { create(:person, first_name: "Inactiva", last_name: "Cancelled") }
      let!(:active_registration) { create(:event_registration, event: event, registrant: active_person, status: "attended") }
      let!(:inactive_registration) { create(:event_registration, event: event, registrant: inactive_person, status: "cancelled") }

      it "shows active and inactive counts" do
        get registrants_event_path(event)

        # registration (default "registered") + active_registration are active
        expect(response.body).to include("Active <span class=\"text-gray-400\">(2)</span>")
        expect(response.body).to include("Inactive <span class=\"text-gray-400\">(1)</span>")
      end

      it "defaults to the active filter, hiding inactive registrants" do
        get registrants_event_path(event)

        expect(response.body).to include("Activa")
        expect(response.body).not_to include("Inactiva")
      end

      it "shows only inactive registrants when filtered to inactive" do
        get registrants_event_path(event, params: { status_filter: "inactive" })

        expect(response.body).to include("Inactiva")
        expect(response.body).not_to include("Activa")
      end

      it "honors an explicit attendance_status over the active/inactive filter" do
        get registrants_event_path(event, params: { attendance_status: "cancelled" })

        expect(response.body).to include("Inactiva")
        expect(response.body).not_to include("Activa")
      end

      it "shows the active registrant count in the page heading" do
        get registrants_event_path(event)

        expect(response.body).to include("Registrants (2)")
      end
    end

    context "organization column" do
      let(:organization) { create(:organization, name: "Helping Hands") }

      # Scopes assertions to the registrant's org cell so generic words like
      # "None" in unrelated filter dropdowns don't cause false matches.
      def org_cell_text
        Nokogiri::HTML(response.body)
          .at_css("tr#registrant-row-#{registration.id} td[data-column-toggle-col='organization']")&.text&.squish
      end

      # Stores a submitted "agency_name" answer for the registrant, mirroring what
      # public registration captures, so the Pending/None chip logic has data.
      def submit_agency_name(name)
        registration_form = Form.find_by(name: "Registration") || create(:form, name: "Registration")
        field = registration_form.form_fields.find_by(field_identifier: "agency_name") ||
          create(:form_field, form: registration_form, field_identifier: "agency_name")
        create(:event_form, :registration, event: event, form: registration_form) unless event.registration_form
        submission = create(:form_submission, person: person, form: registration_form)
        create(:form_answer, form_submission: submission, form_field: field, submitted_answer: name)
      end

      it "links a linked organization to the edit page rather than its profile" do
        create(:event_registration_organization, event_registration: registration, organization: organization)

        get registrants_event_path(event)

        expect(response.body).to include(link_organization_event_registration_path(registration, return_to: "registrants"))
        expect(response.body).not_to include(organization_path(organization))
      end

      it "shows a 'Pending' chip when a registrant submitted an org name but has no linked org" do
        submit_agency_name("Some Unlisted Org")

        get registrants_event_path(event)

        expect(org_cell_text).to include("Pending")
        expect(org_cell_text).not_to include("None")
      end

      it "shows a 'None' chip when a registrant has no linked org and submitted nothing" do
        get registrants_event_path(event)

        expect(org_cell_text).to include("None")
        expect(org_cell_text).not_to include("Pending")
      end

      it "does not show a 'Pending' chip when an org is linked, even if the submitted name differs" do
        create(:event_registration_organization, event_registration: registration, organization: organization)
        submit_agency_name("A Different Unlisted Agency")

        get registrants_event_path(event)

        expect(org_cell_text).to include(organization.name)
        expect(org_cell_text).not_to include("Pending")
      end

      it "does not show 'Pending' when the submitted name matches a linked org" do
        create(:event_registration_organization, event_registration: registration, organization: organization)
        submit_agency_name(organization.name)

        get registrants_event_path(event)

        expect(org_cell_text).to include(organization.name)
        expect(org_cell_text).not_to include("Pending")
      end
    end

    context "readiness filtering" do
      let(:ready_person) { create(:person, first_name: "Reada", last_name: "Paidinfull") }
      let(:not_ready_person) { create(:person, first_name: "Nottaready", last_name: "Owes") }
      let!(:ready_registration) { create(:event_registration, event: event, registrant: ready_person, status: "registered") }
      let!(:not_ready_registration) { create(:event_registration, event: event, registrant: not_ready_person, status: "registered") }

      before do
        # Pay `ready_registration` in full and link an org so it clears the
        # pre-event checklist; `not_ready_registration` stays unpaid → not ready.
        create(:allocation,
          source: create(:payment, amount_cents: event.cost_cents, amount_cents_remaining: event.cost_cents),
          allocatable: ready_registration, amount: event.cost_cents)
        create(:event_registration_organization, event_registration: ready_registration, organization: create(:organization))
      end

      it "renders the combined Status column with the right badge labels" do
        get registrants_event_path(event)

        expect(response.body).to include("Ready")
        expect(response.body).to include("Not ready")
      end

      it "shows a two-word reason under the Not ready badge" do
        get registrants_event_path(event)

        # Nottaready is unpaid on a paid event
        expect(response.body).to include("Payment due")
      end

      it "shows the Certificate pending badge with a cert-type subtext once an event-ready registrant has attended" do
        ready_registration.update!(status: "attended")

        get registrants_event_path(event)

        expect(response.body).to include("Certificate pending")
        expect(response.body).to include(">Registration<")
      end

      it "shows only not-ready registrants when filtered to not_ready" do
        get registrants_event_path(event, params: { readiness: "not_ready" })

        expect(response.body).to include("Nottaready")
        expect(response.body).not_to include("Reada")
      end

      it "shows only ready registrants when filtered to ready" do
        get registrants_event_path(event, params: { readiness: "ready" })

        expect(response.body).to include("Reada")
        expect(response.body).not_to include("Nottaready")
      end

      it "excludes an attended registrant from 'completed' until the certificate is sent" do
        ready_registration.update!(status: "attended")

        get registrants_event_path(event, params: { readiness: "completed" })

        expect(response.body).not_to include("Reada")
        expect(response.body).not_to include("Nottaready")
      end

      it "shows a registrant under 'completed' once attended and the certificate is sent" do
        ready_registration.update!(status: "attended", certificate_sent_at: Time.current)

        get registrants_event_path(event, params: { readiness: "completed" })

        expect(response.body).to include("Reada")
        expect(response.body).not_to include("Nottaready")
      end

      it "does not crash on an invalid readiness filter" do
        get registrants_event_path(event, params: { readiness: "bogus" })

        expect(response).to have_http_status(:ok)
      end
    end

    context "event heading" do
      it "shows the event title and date range after the heading" do
        event.update!(start_date: Time.zone.local(2026, 6, 2, 9), end_date: Time.zone.local(2026, 6, 2, 17))

        get registrants_event_path(event)

        expect(response.body).to include(event.title)
        expect(response.body).to include(event.decorate.date_range)
      end
    end

    context "confirmed column toggle" do
      it "renders the slide toggle for confirmed column" do
        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('data-controller="column-toggle"')
        expect(response.body).to include("Confirmed")
      end

      it "renders confirmed column header hidden by default" do
        get registrants_event_path(event)

        expect(response.body).to include("data-column-toggle-col")
      end

      context "when registrant has a confirmed user" do
        it "shows confirmed check icon" do
          get registrants_event_path(event)

          expect(response.body).to include("fa-check-circle")
        end
      end

      context "when registrant has an unconfirmed user with invite sent" do
        let(:person) { create(:person, user: create(:user, :unconfirmed, welcome_instructions_sent_at: 1.day.ago)) }

        it "shows clock icon" do
          get registrants_event_path(event)

          expect(response.body).to include("fa-solid fa-clock")
        end
      end

      context "when registrant has an unconfirmed user without invite" do
        let(:person) { create(:person, user: create(:user, :unconfirmed)) }

        it "shows invite button" do
          get registrants_event_path(event)

          expect(response.body).to include("Invite")
        end
      end

      context "when registrant has no user" do
        let(:person) { create(:person, user: nil) }

        it "shows create user link" do
          get registrants_event_path(event)

          expect(response.body).to include("Create user")
        end
      end
    end

    context "payment status column" do
      let(:event) { create(:event, cost_cents: 1000) }

      it "shows the due amount and no paid amount when nothing has been paid" do
        get registrants_event_path(event)

        expect(response.body).to include("$10 due")
        expect(response.body).not_to include("Partial")
      end

      it "shows the partial badge when a payment covers part of the cost" do
        payment = create(:payment, person: person, amount_cents: 400, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: registration, amount: 400)

        get registrants_event_path(event)

        expect(response.body).to include("Partial payment · $6 due")
        expect(response.body).not_to include(">Partial payment<")
        expect(response.body).to include("$6 due")
      end

      it "does not show the partial badge when only a scholarship covers part of the cost" do
        scholarship = create(:scholarship, recipient: person, tasks_completed: true, amount_cents: 400)
        create(:allocation, source: scholarship, allocatable: registration, amount: 400)

        get registrants_event_path(event)

        expect(response.body).to include("$6 due")
        expect(response.body).not_to include("Partial")
      end

      it "shows Paid when paid in full" do
        payment = create(:payment, person: person, amount_cents: 1000, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: registration, amount: 1000)

        get registrants_event_path(event)

        expect(response.body).to include(">Paid</span>")
      end

      it "shows a Discounted chip when a discount leaves a balance due" do
        discount = Discount.create!(amount_cents: 400)
        create(:allocation, source: discount, allocatable: registration, amount: 400)

        get registrants_event_path(event)

        expect(response.body).to include("fa-tag")
        expect(response.body).to include("Discounted · $6 due")
        expect(response.body).not_to include(">Discounted<")
        expect(response.body).to include("$6 due")
      end

      it "shows Paid when a discount fully covers the cost" do
        discount = Discount.create!(amount_cents: 1000)
        create(:allocation, source: discount, allocatable: registration, amount: 1000)

        get registrants_event_path(event)

        expect(response.body).to include(">Paid</span>")
        expect(response.body).not_to include(">Discounted<")
      end
    end

    context "registration form icon" do
      let(:reg_form) { create(:form, :standalone, name: "Registration Form") }

      it "shows a blue outline form icon when person submitted the current registration form" do
        create(:event_form, event: event, form: reg_form, role: "registration")
        create(:form_submission, person: person, form: reg_form)

        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('fa-regular fa-file-lines')
        expect(response.body).to include('text-blue-600')
      end

      it "reserves an empty slot (no icon) when person has not submitted, keeping later icons aligned" do
        create(:event_form, event: event, form: reg_form, role: "registration")

        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('fa-file-lines')
        expect(response.body).to include('inline-flex w-4 justify-center')
      end

      it "does not show any form icon when event has no forms" do
        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('fa-file-lines')
      end

      it "shows no form icon when the only submission is for a bulk payment form" do
        bulk_payment_form = create(:form, :standalone, name: "Bulk Payment Form")
        create(:event_form, event: event, form: reg_form, role: "registration")
        create(:event_form, event: event, form: bulk_payment_form, role: "bulk_payment")
        create(:form_submission, person: person, form: bulk_payment_form)

        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('fa-file-lines')
        expect(response.body).to include('inline-flex w-4 justify-center')
      end
    end

    context "scholarship application icon" do
      let(:scholarship_form) { create(:form, :standalone, name: "Scholarship Form") }

      before { create(:event_form, event: event, form: scholarship_form, role: "scholarship") }

      it "shows the scholarship icon when the person submitted the scholarship form" do
        submission = create(:form_submission, person: person, form: scholarship_form, role: "scholarship")
        create(:form_answer, form_submission: submission)

        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("fa-solid fa-hand-holding-heart")
      end

      it "does not show the scholarship icon for a submission with no answers" do
        create(:form_submission, person: person, form: scholarship_form, role: "scholarship")

        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("fa-hand-holding-heart")
      end

      it "does not show the scholarship icon when the person has no scholarship submission" do
        get registrants_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("fa-hand-holding-heart")
      end
    end
  end

  describe "GET /events/:id/registrants with payment and scholarship filters" do
    let(:event) { create(:event, cost_cents: 1_000) }
    let(:paid_person) { create(:person, first_name: "Paid", last_name: "Person") }
    let(:unpaid_person) { create(:person, first_name: "Unpaid", last_name: "Person") }
    let(:scholarship_person) { create(:person, first_name: "Scholar", last_name: "Person") }

    let!(:paid_reg) do
      reg = create(:event_registration, event: event, registrant: paid_person)
      create(:allocation, source: create(:payment, amount_cents: 1_000, amount_cents_remaining: 1_000),
                          allocatable: reg, amount: 1_000)
      reg
    end
    let!(:unpaid_reg) { create(:event_registration, event: event, registrant: unpaid_person) }
    let(:pending_scholarship_person) { create(:person, first_name: "Pending", last_name: "Person") }
    let!(:scholarship_reg) do
      reg = create(:event_registration, event: event, registrant: scholarship_person)
      scholarship = create(:scholarship, recipient: scholarship_person, tasks_completed: true, amount_cents: 1_000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1_000)
      reg
    end
    let!(:pending_scholarship_reg) do
      reg = create(:event_registration, event: event, registrant: pending_scholarship_person)
      scholarship = create(:scholarship, recipient: pending_scholarship_person, tasks_completed: false, amount_cents: 500)
      create(:allocation, source: scholarship, allocatable: reg, amount: 500)
      reg
    end

    before { sign_in admin }

    it "filters to paid-in-full registrants" do
      get registrants_event_path(event, payment_status: "paid")
      expect(response.body).to include("Paid Person")
      expect(response.body).to include("Scholar Person")
      expect(response.body).not_to include("Unpaid Person")
    end

    it "filters to not-paid-in-full registrants" do
      get registrants_event_path(event, payment_status: "unpaid")
      expect(response.body).to include("Unpaid Person")
      expect(response.body).not_to include("Paid Person")
    end

    it "filters to all scholarship recipients" do
      get registrants_event_path(event, scholarship: "yes")
      expect(response.body).to include("Scholar Person")
      expect(response.body).to include("Pending Person")
      expect(response.body).not_to include("Paid Person")
      expect(response.body).not_to include("Unpaid Person")
    end

    it "filters to recipients whose tasks are complete" do
      get registrants_event_path(event, scholarship: "complete")
      expect(response.body).to include("Scholar Person")
      expect(response.body).not_to include("Pending Person")
    end

    it "filters to recipients whose tasks are not complete" do
      get registrants_event_path(event, scholarship: "incomplete")
      expect(response.body).to include("Pending Person")
      expect(response.body).not_to include("Scholar Person")
    end
  end

  describe "GET /events/:id/registrants with the CE status filter" do
    let(:event) { create(:event, cost_cents: 1_000) }
    let(:complete_person) { create(:person, first_name: "Complete", last_name: "Person") }
    let(:missing_person) { create(:person, first_name: "Missing", last_name: "Person") }
    let(:none_person) { create(:person, first_name: "Noce", last_name: "Person") }

    let!(:complete_reg) do
      reg = create(:event_registration, event: event, registrant: complete_person,
                                         ce_credit_requested: true, ce_license_number: "ABC123", ce_hours_requested: 3)
      create(:allocation, source: create(:payment, amount_cents: 1_000, amount_cents_remaining: 1_000),
                          allocatable: reg, amount: 1_000)
      reg
    end
    let!(:missing_reg) { create(:event_registration, event: event, registrant: missing_person, ce_credit_requested: true) }
    let!(:none_reg) { create(:event_registration, event: event, registrant: none_person, ce_credit_requested: false) }

    before do
      offer_ce!(event)
      sign_in admin
    end

    it "shows the CE status column and filter when the event offers CE" do
      get registrants_event_path(event)
      expect(response.body).to include("CE status")
      expect(response.body).to include('data-column-toggle-group-value="ce"')
    end

    it "renders the CE status column on by default, with a toggle to hide it" do
      get registrants_event_path(event)
      # CE column markers render visible (no `hidden` class) since the toggle defaults on…
      expect(response.body).to include('data-column-toggle-col="ce"')
      expect(response.body).not_to match(/class="[^"]*\bhidden\b[^"]*"[^>]*data-column-toggle-col="ce"/)
      # …and the toggle switch shows its on-state.
      expect(response.body).to include('data-column-toggle-group-value="ce"')
    end

    it "filters to all CE requests" do
      get registrants_event_path(event, ce_status: "requested")
      expect(response.body).to include("Complete Person")
      expect(response.body).to include("Missing Person")
      expect(response.body).not_to include("Noce Person")
    end

    it "filters to CE requests missing a license number" do
      get registrants_event_path(event, ce_status: "license_not_provided")
      expect(response.body).to include("Missing Person")
      expect(response.body).not_to include("Complete Person")
    end

    it "filters to CE requests missing hours" do
      get registrants_event_path(event, ce_status: "hours_not_provided")
      expect(response.body).to include("Missing Person")
      expect(response.body).not_to include("Complete Person")
    end

    it "filters to paid CE requests" do
      get registrants_event_path(event, ce_status: "paid")
      expect(response.body).to include("Complete Person")
      expect(response.body).not_to include("Missing Person")
    end

    it "does not crash on an invalid ce_status" do
      get registrants_event_path(event, ce_status: "bogus")
      expect(response).to have_http_status(:ok)
    end

    it "hides CE entirely when the event's registration form doesn't offer CE" do
      plain_event = create(:event)
      create(:event_registration, event: plain_event, ce_credit_requested: true)
      get registrants_event_path(plain_event)
      expect(response.body).not_to include("CE status")
    end

    it "includes a CE status column in the CSV export" do
      get registrants_event_path(event, format: :csv)
      expect(response.body).to include("CE status")
      expect(response.body).to include("Incomplete")
    end
  end

  describe "GET /events/:id/registrants CE status column states" do
    let(:event) { offer_ce!(create(:event, cost_cents: 1_000)) }
    let(:person) { create(:person, first_name: "Cee", last_name: "Ee") }

    before { sign_in admin }

    # The CE chip is the only content of the CE column cell, so its squished text
    # is the chip label (the trailing link arrow icon contributes no text).
    def ce_chip_text
      Nokogiri::HTML(response.body).at_css('td[data-column-toggle-col="ce"]')&.text&.squish
    end

    it "shows Create when CE was not requested" do
      create(:event_registration, event: event, registrant: person, ce_credit_requested: false)
      get registrants_event_path(event)
      expect(ce_chip_text).to eq("Create")
    end

    it "shows Requested when requested but no CE registration record exists yet" do
      create(:event_registration, event: event, registrant: person, ce_credit_requested: true)
      get registrants_event_path(event)
      expect(ce_chip_text).to eq("Requested")
    end

    it "shows No license # once a CE record exists without a license number" do
      reg = create(:event_registration, event: event, registrant: person, ce_credit_requested: true)
      create(:continuing_education_registration, event_registration: reg,
        professional_license: create(:professional_license, :placeholder, person: person))
      get registrants_event_path(event)
      expect(ce_chip_text).to eq("No license #")
    end

    it "shows Filed once a license is on file but the CE balance is unpaid" do
      reg = create(:event_registration, event: event, registrant: person, ce_credit_requested: true)
      create(:continuing_education_registration, event_registration: reg, cost_cents: 15_000,
        professional_license: create(:professional_license, person: person))
      get registrants_event_path(event)
      expect(ce_chip_text).to eq("Filed")
    end

    it "shows Recipient when the CE balance is paid" do
      reg = create(:event_registration, event: event, registrant: person, ce_credit_requested: true)
      cer = create(:continuing_education_registration, event_registration: reg, cost_cents: 15_000,
        professional_license: create(:professional_license, person: person))
      create(:allocation, source: create(:payment, amount_cents: 15_000, amount_cents_remaining: 15_000),
        allocatable: cer, amount: 15_000)
      get registrants_event_path(event)
      expect(ce_chip_text).to eq("Recipient")
    end
  end

  describe "GET /events/:id/registrants with state and county filters" do
    let(:ca_person) { create(:person, first_name: "Cali", last_name: "Person") }
    let(:ny_person) { create(:person, first_name: "York", last_name: "Person") }
    # Same county name ("Kings") in a different state, to prove disambiguation.
    let(:ca_kings_person) { create(:person, first_name: "Caliking", last_name: "Person") }

    let!(:ca_reg) { create(:event_registration, event: event, registrant: ca_person) }
    let!(:ny_reg) { create(:event_registration, event: event, registrant: ny_person) }
    let!(:ca_kings_reg) { create(:event_registration, event: event, registrant: ca_kings_person) }

    before do
      create(:address, addressable: ca_person, state: "CA", county: "Los Angeles")
      create(:address, addressable: ny_person, state: "NY", county: "Kings")
      create(:address, addressable: ca_kings_person, state: "CA", county: "Kings")
      sign_in admin
    end

    it "filters registrants by state" do
      get registrants_event_path(event, state: "CA")
      expect(response.body).to include("Cali Person")
      expect(response.body).not_to include("York Person")
    end

    it "filters registrants by a state-scoped county value" do
      get registrants_event_path(event, county: "NY|Kings")
      expect(response.body).to include("York Person")
      expect(response.body).not_to include("Cali Person")
      expect(response.body).not_to include("Caliking Person")
    end

    it "filters registrants by a hyphenated registrant id list" do
      get registrants_event_path(event, registrant_ids: ca_person.id.to_s)
      expect(response.body).to include("Cali Person")
      expect(response.body).not_to include("York Person")
    end

    it "filters registrants by sector" do
      sector = create(:sector)
      create(:sectorable_item, sector: sector, sectorable: ca_person)

      get registrants_event_path(event, sector: sector.id)
      expect(response.body).to include("Cali Person")
      expect(response.body).not_to include("York Person")
    end
  end

  describe "GET /events/:id/onboarding" do
    let(:person) { create(:person, first_name: "Onboard", last_name: "Ready") }
    let!(:registration) { create(:event_registration, event: event, registrant: person) }

    before do
      offer_ce!(event)
      sign_in admin
    end

    it "renders the onboarding matrix with the checklist columns" do
      get onboarding_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Onboarding")
      expect(response.body).to include("Mailchimp")
      expect(response.body).to include("CMS")
      expect(response.body).to include("Portal invite")
      expect(response.body).to include("CE requested")
      expect(response.body).to include("License #")
      expect(response.body).to include("Event attendance")
      expect(response.body).to include("Onboard")
    end

    it "offers a Create scholarship link when the registrant has none" do
      get onboarding_event_path(event)

      expect(response.body).to include("Create")
      # SGID carries an expiry, so assert the stable parts of the new-scholarship link.
      expect(response.body).to include("/scholarships/new?allocatable_sgid=")
      expect(response.body).to include("return_to=onboarding")
    end

    it "shows separately sortable first name, last name, and email columns" do
      get onboarding_event_path(event)

      # Three distinct sortable headers plus the registrant's split name + email.
      expect(response.body).to match(/First\s*<span data-sort-indicator/)
      expect(response.body).to match(/Last\s*<span data-sort-indicator/)
      expect(response.body).to match(/Email\s*<span data-sort-indicator/)
      expect(response.body).to include("Ready")
      expect(response.body).to include(person.preferred_email)
    end

    it "wires up click-to-sort on the matrix" do
      get onboarding_event_path(event)

      expect(response.body).to include('data-controller="table-sort"')
      expect(response.body).to include('data-table-sort-target="body"')
      expect(response.body).to include('data-table-sort-target="header"')
    end

    it "gives each row a stable anchor id and highlights the requested one" do
      get onboarding_event_path(event, highlight: registration.id)

      expect(response.body).to include("id=\"onboarding-row-#{registration.id}\"")
      expect(response.body).to include("ring-yellow-500")
    end

    it "shows an Onboarding back-link to the row on registration edit" do
      get edit_event_registration_path(registration, return_to: "onboarding")

      expect(response.body).to include("onboarding-row-#{registration.id}")
      expect(response.body).to include("highlight=#{registration.id}")
    end

    it "exports the matrix as CSV" do
      get onboarding_event_path(event, format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include("First name,Last name,Email")
      expect(response.body).to include("Mailchimp")
      expect(response.body).to include("CE requested,CE hours,CE amount,CE license")
      expect(response.body).to include("Portal user status,Portal access")
      expect(response.body).to include("Comments,Flagged comments")
      expect(response.body).to include("Ready")

      # Header and data rows must have matching column counts (no misalignment).
      rows = CSV.parse(response.body)
      expect(rows.length).to be > 1
      rows[1..].each { |data_row| expect(data_row.length).to eq(rows.first.length) }
    end

    it "shows registration comments joined by ::: linked to the comments section" do
      create(:comment, commentable: registration, body: "First note")
      create(:comment, commentable: registration, body: "Second note")

      get onboarding_event_path(event)

      expect(response.body).to include("Second note ::: First note").or include("First note ::: Second note")
      expect(response.body).to include("#comments-section")
    end

    it "renders registrants with payment and grant-funded scholarship allocations" do
      paid_event = create(:event, cost_cents: 2_000)
      paid_reg = create(:event_registration, event: paid_event, registrant: person)
      payment = create(:payment, amount_cents: 500, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: paid_reg, amount: 500)
      grant = create(:grant, name: "Helping Fund")
      scholarship = create(:scholarship, recipient: person, grant: grant, amount_cents: 1_500)
      create(:allocation, source: scholarship, allocatable: paid_reg, amount: 1_500)

      get onboarding_event_path(paid_event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Helping Fund")
    end

    it "reports Paid amount as payments only, not scholarship coverage" do
      paid_event = create(:event, cost_cents: 2_000)
      paid_reg = create(:event_registration, event: paid_event, registrant: person)
      payment = create(:payment, amount_cents: 500, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: paid_reg, amount: 500)
      scholarship = create(:scholarship, recipient: person, amount_cents: 1_500)
      create(:allocation, source: scholarship, allocatable: paid_reg, amount: 1_500)

      get onboarding_event_path(paid_event, format: :csv)

      row = CSV.parse(response.body).find { |r| r[1] == person.last_name }
      headers = CSV.parse(response.body).first
      paid_amount = row[headers.index("Paid amount")]
      scholarship_amount = row[headers.index("Scholarship amount")]

      expect(paid_amount).to eq("$5")        # the $5 payment, NOT the $15 scholarship
      expect(scholarship_amount).to eq("$15")
    end

    it "redirects a non-admin" do
      sign_in user
      get onboarding_event_path(event)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /event_registrations/:id/update_onboarding" do
    let(:registration) { create(:event_registration, event: event) }

    before { sign_in admin }

    it "creates an audited completion row when a checklist step is checked" do
      expect {
        patch update_onboarding_event_registration_path(registration),
              params: { field: "set_up_in_mailchimp", value: "1" },
              as: :turbo_stream
      }.to change { registration.checklist_completions.where(step: "set_up_in_mailchimp").count }.by(1)

      completion = registration.checklist_completions.find_by(step: "set_up_in_mailchimp")
      expect(completion.completed_by).to eq(admin)
      expect(completion.completed_at).to be_present
    end

    it "removes the completion row when a checklist step is unchecked" do
      create(:event_registration_checklist_completion, event_registration: registration, step: "set_up_in_mailchimp")

      expect {
        patch update_onboarding_event_registration_path(registration),
              params: { field: "set_up_in_mailchimp", value: "0" },
              as: :turbo_stream
      }.to change { registration.checklist_completions.where(step: "set_up_in_mailchimp").count }.by(-1)
    end

    it "toggles a day-attendance boolean" do
      patch update_onboarding_event_registration_path(registration),
            params: { field: "completed_day_1", value: "1" },
            as: :turbo_stream

      expect(registration.reload.completed_day_1).to be(true)
    end

    it "saves a fee note" do
      patch update_onboarding_event_registration_path(registration),
            params: { field: "fee_note", value: "PAID FOR TAC261" },
            as: :turbo_stream

      expect(registration.reload.fee_note).to eq("PAID FOR TAC261")
    end


    it "rejects an unknown field" do
      patch update_onboarding_event_registration_path(registration),
            params: { field: "drop_table", value: "1" },
            as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "redirects a non-admin without changing anything" do
      sign_in user
      expect {
        patch update_onboarding_event_registration_path(registration),
              params: { field: "set_up_in_mailchimp", value: "1" }
      }.not_to change(EventRegistrationChecklistCompletion, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /events/:id/dashboard" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:person) { create(:person) }
    let(:organization) { create(:organization, name: "Overview Org") }
    let!(:registration) do
      create(:affiliation, person: person, organization: organization)
      create(:event_registration, event: event, registrant: person, status: "registered")
    end

    context "as admin" do
      before { sign_in admin }

      it "renders the dashboard with registrant count and organizations" do
        get dashboard_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Dashboard")
        expect(response.body).to include("Overview Org")
      end

      it "shows a program status badge next to each organization" do
        get dashboard_event_path(event)

        # The org list lives inside a collapsed <details>, so match hidden nodes too.
        page = Capybara.string(response.body)
        expect(page).to have_css("span[title='New']", text: "N", visible: :all)
      end

      it "renders the payments section with totals for a paid event" do
        create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                            allocatable: registration, amount: 6_000)

        get dashboard_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Registration fees")
        expect(response.body).to include("CE fees")
        expect(response.body).to include("Paid")
        expect(response.body).to include("$60")
      end

      it "shows unallocated bulk payments in the equation, linking to the bulk payments page" do
        bulk_form = create(:form)
        create(:event_form, event: event, form: bulk_form, role: "bulk_payment")
        submission = create(:form_submission, person: person, form: bulk_form, event: event, role: "bulk_payment")
        create(:payment, person: person, form_submission: submission,
               amount_cents: 5_000, amount_cents_remaining: 5_000)

        get dashboard_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Unallocated bulk payments")
        expect(response.body).to include(bulk_payments_event_path(event))
      end

      it "shows the bulk payments term at zero when nothing is unallocated" do
        get dashboard_event_path(event)

        expect(response.body).not_to include("Unallocated bulk payments")
        expect(response.body).to include("Bulk payments")
        expect(response.body).to include(bulk_payments_event_path(event))
      end
    end

    context "as non-admin non-owner" do
      before { sign_in user }

      it "redirects" do
        get dashboard_event_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /events/:id/background" do
    let(:event) { create(:event) }
    let(:person) { create(:person, first_name: "Ada", last_name: "Lovelace") }
    let(:organization) { create(:organization, name: "Background Org") }
    let!(:registration) do
      create(:affiliation, person: person, organization: organization)
      create(:event_registration, event: event, registrant: person, status: "registered")
    end

    context "as admin" do
      before { sign_in admin }

      it "renders the registrant roster with names and program" do
        get background_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Get to know the registrants")
        expect(response.body).to include("Ada")
        expect(response.body).to include("Lovelace")
        expect(response.body).to include("Background Org")
      end

      it "links each registrant row to their profile" do
        get background_event_path(event)

        expect(response.body).to include(person_path(person))
      end

      it "shows a countries breakdown from registrant addresses" do
        create(:address, addressable: person, state: "CA", country: "Canada", inactive: false)

        get background_event_path(event)

        expect(response.body).to include("Canada")
        expect(response.body).to include("Countries")
      end

      it "shows a location column with the registrant's state abbreviation" do
        create(:address, addressable: person, state: "WY", country: nil, inactive: false)

        get background_event_path(event)

        expect(response.body).to include("Location")
        expect(response.body).to include("WY")
      end

      it "shows the ISO country code in the location column for international registrants" do
        create(:address, addressable: person, state: "ON", country: "Canada", inactive: false)

        get background_event_path(event)

        expect(response.body).to include("CAN")
      end

      it "shows a school districts breakdown from registrant addresses" do
        create(:address, addressable: person, state: "CA", district: "Compton Unified", inactive: false)

        get background_event_path(event)

        expect(response.body).to include("School districts")
        expect(response.body).to include("Compton Unified")
      end

      it "shows a sectors count box from registrants' sectors" do
        create(:sectorable_item, sector: create(:sector, name: "Sexual Assault"), sectorable: person)
        create(:sectorable_item, sector: create(:sector, name: "Mental Health"), sectorable: person)

        get background_event_path(event)

        expect(response.body).to include("Sectors")
        expect(response.body).to include("Sexual Assault")
      end

      it "labels the organizations count box and breaks it down by program status" do
        get background_event_path(event)

        expect(response.body).to include("Organizations")
        expect(response.body).to match(/\d+ new · \d+ ongoing · \d+ reinstated/)
      end

      it "shows a program-status column in the registrant roster" do
        get background_event_path(event)

        # "Background Org" is the registrant's first-facilitator program → New.
        expect(response.body).to include("Status")
        expect(response.body).to include("New")
      end

      it "renders the states breakdown as a US choropleth map fed by per-state counts" do
        create(:address, addressable: person, state: "CA", inactive: false)

        get background_event_path(event)

        expect(response.body).to include("States")
        expect(response.body).to include('data-controller="us-map-chart"')
        expect(response.body).to include("CA")
      end

      it "excludes registrants with an inactive status" do
        cancelled = create(:person, first_name: "Grace", last_name: "Hopper")
        create(:event_registration, event: event, registrant: cancelled, status: "cancelled")

        get background_event_path(event)

        expect(response.body).to include("Lovelace")
        expect(response.body).not_to include("Hopper")
      end

      it "shows a primary age group breakdown from registration responses" do
        registration_form = create(:form, name: "Registration")
        field = create(:form_field, form: registration_form, field_identifier: "primary_age_group",
                                    answer_type: :multi_select_checkbox)
        create(:event_form, event: event, form: registration_form, role: "registration")
        age_range = create(:category_type, name: "AgeRange")
        adults = create(:category, name: "Adults", category_type: age_range)
        submission = create(:form_submission, person: person, form: registration_form)
        create(:form_answer, form_submission: submission, form_field: field, submitted_answer: adults.id.to_s)

        get background_event_path(event)

        expect(response.body).to include("Primary age group")
        expect(response.body).to include("Adults")
        # Percentages render as always-visible text (not hover-only), so they read on mobile.
        expect(response.body).to include("100.0%")
      end

      it "shows a life experiences breakdown from registrants' StoryPopulation tags" do
        story_population = create(:category_type, name: "StoryPopulation")
        experience = create(:category, name: "Veterans", category_type: story_population)
        create(:categorizable_item, category: experience, categorizable: person)

        get background_event_path(event)

        expect(response.body).to include("Life experiences")
        expect(response.body).to include("Veterans")
      end

      it "hides the life experiences and settings cards when registrants have no tags" do
        get background_event_path(event)

        expect(response.body).not_to include("Life experiences")
        expect(response.body).not_to include("Settings")
      end

      it "links scholarship recipients to their entry on the recipients page" do
        scholarship = create(:scholarship, recipient: person)
        create(:allocation, source: scholarship, allocatable: registration)

        get background_event_path(event)

        expect(response.body).to include("fa-graduation-cap")
        expect(response.body).to include("#{recipients_event_path(event)}#participant-#{registration.slug}")
      end

      it "does not show a recipients link for registrants without a scholarship" do
        get background_event_path(event)

        expect(response.body).not_to include("#scholarship_")
      end
    end

    context "as non-admin non-owner" do
      before { sign_in user }

      it "redirects" do
        get background_event_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /events/:id/staff" do
    let(:public_event) { create(:event, :published, :publicly_visible) }
    let(:staff_member) { create(:person, first_name: "Ada", last_name: "Lovelace") }

    it "renders the curated staff roster for a publicly visible event without authentication" do
      create(:event_staff, event: public_event, person: staff_member, title: "Lead facilitator")

      get staff_event_path(public_event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Meet the staff")
      expect(response.body).to include("Ada")
      expect(response.body).to include("Lovelace")
      expect(response.body).to include("Lead facilitator")
    end

    it "shows only people on the staff roster, not event registrants" do
      registrant_only = create(:person, first_name: "Grace", last_name: "Hopper")
      create(:event_staff, event: public_event, person: staff_member)
      create(:event_registration, event: public_event, registrant: registrant_only, status: "registered")

      get staff_event_path(public_event)

      expect(response.body).to include("Ada")
      expect(response.body).not_to include("Grace")
    end

    it "flags a staff member who is expected to attend" do
      create(:event_staff, event: public_event, person: staff_member, expected_to_attend: true)

      get staff_event_path(public_event)

      expect(response.body).to include("Attending")
    end

    context "when the event has ended" do
      let(:ended_event) { create(:event, :published, :ended) }

      it "redirects an unauthenticated visitor" do
        get staff_event_path(ended_event)
        expect(response).to redirect_to(root_path)
      end

      it "allows an admin to view" do
        sign_in admin
        get staff_event_path(ended_event)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /events/:id/recipients" do
    let(:event) { create(:event, start_date: 1.month.from_now, end_date: 1.month.from_now + 1.day) }
    let(:registration_form) { create(:form, name: "Registration") }
    let(:scholarship_form) { create(:form, :scholarship) }
    let(:applicant) { create(:person, first_name: "Tara", last_name: "Gallagher") }
    let(:impact_field) do
      create(:form_field, form: scholarship_form, name: "How will this help the people you serve?",
                          field_identifier: "impact_description")
    end
    let(:sector_field) do
      create(:form_field, form: registration_form, name: "Primary sector", field_identifier: "additional_sectors")
    end

    before do
      create(:event_form, :registration, event: event, form: registration_form)
      create(:event_form, :scholarship, event: event, form: scholarship_form)
      create(:event_registration, event: event, registrant: applicant, status: "registered", scholarship_requested: true)

      # Sector captured as a registration answer (resolved from the sector id).
      sector = create(:sector, name: "Sexual Assault")
      reg_submission = create(:form_submission, person: applicant, form: registration_form)
      create(:form_answer, form_submission: reg_submission, form_field: sector_field, submitted_answer: sector.id.to_s)

      # Scholarship answer rides on a separate scholarship submission.
      sch_submission = create(:form_submission, person: applicant, form: scholarship_form, role: "scholarship")
      create(:form_answer, form_submission: sch_submission, form_field: impact_field, submitted_answer: "It will let me reach more survivors.")
    end

    context "as admin" do
      before { sign_in admin }

      it "renders each applicant with their sector resolved from the form answer and scholarship answers" do
        get recipients_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tara Gallagher")
        expect(response.body).to include("Sexual Assault")
        expect(response.body).to include("How will this help the people you serve?")
        expect(response.body).to include("It will let me reach more survivors.")
      end

      it "renders the collapsible card controls and an expand/collapse-all button" do
        get recipients_event_path(event)

        expect(response.body).to include('data-controller="expandable-cards scholarship-status-toggle"')
        expect(response.body).to include("Collapse all")
        expect(response.body).to include('data-controller="expandable-card"')
        expect(response.body).to include("expandable-card#toggle")
        expect(response.body).to include('data-expandable-card-target="body"')
      end

      it "renders a page-wide toggle to show/hide scholarship status, shown by default" do
        get recipients_event_path(event)

        expect(response.body).to include('data-controller="expandable-cards scholarship-status-toggle"')
        expect(response.body).to include('data-action="scholarship-status-toggle#toggle"')
        expect(response.body).to include('data-scholarship-status-toggle-shown-value="true"')
        expect(response.body).to include("Hide scholarship status")
      end

      it "shows each recipient's awarded amount and completed tasks status" do
        event.update!(cost_cents: 50_000)
        registration = event.event_registrations.find_by(registrant: applicant)
        scholarship = create(:scholarship, recipient: applicant, amount_cents: 50_000, tasks_completed: true)
        create(:allocation, source: scholarship, allocatable: registration, amount: 50_000)

        get recipients_event_path(event)

        expect(response.body).to include('data-scholarship-status-toggle-target="status"')
        expect(response.body).to include("$500")
        expect(response.body).to include("Tasks completed")
      end

      it "links each scholarship to its edit page, returning to this recipients page" do
        event.update!(cost_cents: 50_000)
        registration = event.event_registrations.find_by(registrant: applicant)
        scholarship = create(:scholarship, recipient: applicant, amount_cents: 50_000, tasks_completed: true)
        create(:allocation, source: scholarship, allocatable: registration, amount: 50_000)

        get recipients_event_path(event)

        expect(response.body).to include(CGI.escapeHTML(edit_scholarship_path(scholarship, return_to: "recipients", participant: registration.slug)))
      end

      it "names the funding donor when the scholarship is drawn from a grant" do
        registration = event.event_registrations.find_by(registrant: applicant)
        org = create(:organization, name: "Joyful Heart Foundation")
        grant = create(:grant, name: "Healing Arts Fund", donor: org, amount_cents: 100_000)
        scholarship = create(:scholarship, recipient: applicant, grant: grant, amount_cents: 1_000, tasks_completed: true)
        create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

        get recipients_event_path(event)

        expect(response.body).to include("Funded by")
        expect(response.body).to include("Joyful Heart Foundation")
      end

      it "omits the donor line for a scholarship with no parent grant" do
        registration = event.event_registrations.find_by(registrant: applicant)
        scholarship = create(:scholarship, recipient: applicant, amount_cents: 1_000, tasks_completed: true)
        create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

        get recipients_event_path(event)

        expect(response.body).not_to include("Funded by")
      end

      it "flags a recipient whose tasks are still outstanding" do
        registration = event.event_registrations.find_by(registrant: applicant)
        scholarship = create(:scholarship, recipient: applicant, amount_cents: 1_000, tasks_completed: false)
        create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

        get recipients_event_path(event)

        expect(response.body).to include("$10")
        expect(response.body).to include("Tasks outstanding")
      end

      it "renders the tasks status as an inline toggle that flips the completed state" do
        registration = event.event_registrations.find_by(registrant: applicant)
        scholarship = create(:scholarship, recipient: applicant, amount_cents: 1_000, tasks_completed: false)
        create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

        get recipients_event_path(event)

        expect(response.body).to include(toggle_tasks_scholarship_path(scholarship))
        expect(response.body).to include("Mark tasks complete")
      end

      it "shows the non-facilitator affiliation's title and linked organization, excluding facilitator roles" do
        org = create(:organization, name: "Safe Harbor of Sheboygan")
        create(:affiliation, person: applicant, organization: org,
                             title: "Prevention, Education, and Outreach Specialist", start_date: 1.year.ago)
        create(:affiliation, person: applicant, organization: create(:organization, name: "Facilitator Org"),
                             title: "Facilitator", start_date: 1.year.ago)

        get recipients_event_path(event)

        expect(response.body).to include("Prevention, Education, and Outreach Specialist")
        expect(response.body).to include("Safe Harbor of Sheboygan")
        expect(response.body).to include(organization_path(org))
        expect(response.body).not_to include("Facilitator Org")
      end

      it "excludes registrants who did not request a scholarship" do
        other = create(:person, first_name: "Pat", last_name: "Plain")
        create(:event_registration, event: event, registrant: other, status: "registered", scholarship_requested: false)

        get recipients_event_path(event)

        expect(response.body).not_to include("Pat Plain")
      end

      it "renders each recipient's tagged age groups as chips, primary ones starred" do
        age_type = create(:category_type, name: "AgeRange", published: true)
        teens = create(:category, :published, category_type: age_type, name: "13-17")
        adults = create(:category, :published, category_type: age_type, name: "18+")
        applicant.tag_age_groups(primary_ids: [ teens.id ], additional_ids: [ adults.id ])

        get recipients_event_path(event)

        page = Capybara.string(response.body)
        expect(page).to have_content("13-17")
        expect(page).to have_content("18+")
        # The primary group leads with the starred lime chip from the shared partial.
        expect(page).to have_css("span.text-lime-800 i.fa-star")
      end

      it "shows the org linked to its website on the left and the bold recipient name linked to their profile on the right" do
        applicant.update!(shoutout_text: "Grateful to bring art to the survivors we serve.")
        event.event_registrations.find_by(registrant: applicant).update!(shoutout: true)
        org = create(:organization, name: "New Economics for Women", website_url: "https://newecon.example.org")
        create(:affiliation, person: applicant, organization: org)

        get recipients_event_path(event)

        expect(response.body).to include("Shout outs")
        expect(response.body).to include("New Economics for Women")
        expect(response.body).to include("https://newecon.example.org")
        expect(response.body).to include("Tara Gallagher")
        expect(response.body).to include(person_path(applicant))
        expect(response.body).to include("Grateful to bring art to the survivors we serve.")
      end

      it "links the org to its profile page when it has no website" do
        applicant.update!(shoutout_text: "Art is how we heal.")
        event.event_registrations.find_by(registrant: applicant).update!(shoutout: true)
        org = create(:organization, name: "Quiet Org", website_url: nil)
        create(:affiliation, person: applicant, organization: org)

        get recipients_event_path(event)

        expect(response.body).to include(organization_path(org))
      end

      it "shows the recipient's primary sector and age group in parentheses after their name" do
        age_range = create(:category_type, name: "AgeRange")
        applicant.sectorable_items.create!(sector: create(:sector, name: "Domestic Violence"), is_primary: true)
        create(:categorizable_item, category: create(:category, name: "Teens", category_type: age_range), categorizable: applicant)
        applicant.update!(shoutout_text: "Here to help.")
        event.event_registrations.find_by(registrant: applicant).update!(shoutout: true)

        get recipients_event_path(event)

        expect(response.body).to include("(Domestic Violence, Teens)")
      end

      it "omits the shout-out block for registrants who did not opt in" do
        applicant.update!(shoutout_text: "I have text but did not opt in.")

        get recipients_event_path(event)

        expect(response.body).not_to include("Shout outs")
      end
    end

    context "as non-admin non-owner" do
      before { sign_in user }

      it "redirects" do
        get recipients_event_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "Google Analytics snippets" do
    context "as admin" do
      before { sign_in admin }

      it "saves snippet fields on update" do
        patch event_path(event), params: { event: {
          ga4_snippet: "<script>console.log('GA4')</script>",
          gtm_head_snippet: "<script>console.log('GTM Head')</script>",
          gtm_body_snippet: "<script>console.log('GTM Body')</script>"
        } }
        event.reload
        expect(event.ga4_snippet).to eq("<script>console.log('GA4')</script>")
        expect(event.gtm_head_snippet).to eq("<script>console.log('GTM Head')</script>")
        expect(event.gtm_body_snippet).to eq("<script>console.log('GTM Body')</script>")
      end

      it "renders snippets on show page" do
        event.update!(
          ga4_snippet: "<script>console.log('GA4')</script>",
          gtm_head_snippet: "<script>console.log('GTM Head')</script>",
          gtm_body_snippet: "<script>console.log('GTM Body')</script>"
        )
        get event_path(event)
        expect(response.body).to include("console.log('GA4')")
        expect(response.body).to include("console.log('GTM Head')")
        expect(response.body).to include("console.log('GTM Body')")
      end

      it "does not render snippets when not set" do
        get event_path(event)
        expect(response.body).not_to include("ga4_snippet")
        expect(response.body).not_to include("gtm_head_snippet")
        expect(response.body).not_to include("gtm_body_snippet")
      end
    end

    context "as non-admin owner" do
      let(:owned_event) { create(:event, created_by: user) }

      before { sign_in user }

      it "ignores snippet params on update" do
        patch event_path(owned_event), params: { event: {
          ga4_snippet: "<script>alert('xss')</script>",
          gtm_head_snippet: "<script>alert('xss')</script>",
          gtm_body_snippet: "<script>alert('xss')</script>"
        } }
        owned_event.reload
        expect(owned_event.ga4_snippet).to be_nil
        expect(owned_event.gtm_head_snippet).to be_nil
        expect(owned_event.gtm_body_snippet).to be_nil
      end
    end
  end

  describe "event staff" do
    let(:published_event) { create(:event, :published) }
    let(:staffer) { create(:person, first_name: "Dana", last_name: "Reed") }

    describe "GET /staff" do
      it "shows connected staff with their title in bold" do
        create(:event_staff, event: published_event, person: staffer, title: "Lead facilitator")
        sign_in admin
        get staff_event_path(published_event)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Dana Reed")
        expect(response.body).to include("Lead facilitator")
      end

      it "links admins to the edit staff page" do
        sign_in admin
        get staff_event_path(published_event)
        expect(response.body).to include(edit_staff_event_path(published_event))
      end
    end

    describe "GET /staff/edit" do
      it "renders for an admin" do
        sign_in admin
        get edit_staff_event_path(published_event)
        expect(response).to have_http_status(:ok)
      end

      it "renders the bio control and the person's profile bio for an existing staff member" do
        staffer.update!(bio: "A seasoned facilitator", profile_show_bio: true)
        create(:event_staff, event: published_event, person: staffer)
        sign_in admin
        get edit_staff_event_path(published_event)
        expect(response.body).to include("event-staff-bio")
        expect(response.body).to include("Profile bio")
        expect(response.body).to include("A seasoned facilitator")
      end

      it "redirects a non-admin" do
        sign_in user
        get edit_staff_event_path(published_event)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /staff" do
      it "rejects adding the same person to the staff twice in one submission" do
        sign_in admin
        expect {
          patch staff_event_path(published_event), params: {
            event: {
              event_staffs_attributes: {
                "0" => { person_id: staffer.id, title: "Lead facilitator" },
                "1" => { person_id: staffer.id, title: "Assistant" }
              }
            }
          }
        }.not_to change(EventStaff, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "adds a staff member to the event" do
        sign_in admin
        expect {
          patch staff_event_path(published_event), params: {
            event: {
              event_staffs_attributes: {
                "0" => { person_id: staffer.id, title: "Staff", expected_to_attend: "1" }
              }
            }
          }
        }.to change(EventStaff, :count).by(1)
        staff = published_event.event_staffs.last
        expect(staff.person).to eq(staffer)
        expect(staff.title).to eq("Staff")
        expect(staff.expected_to_attend).to be(true)
        expect(response).to redirect_to(staff_event_path(published_event))
      end

      it "saves an optional event-specific bio that overrides the profile bio" do
        sign_in admin
        patch staff_event_path(published_event), params: {
          event: {
            event_staffs_attributes: {
              "0" => { person_id: staffer.id, title: "Staff", bio: "Custom event bio" }
            }
          }
        }
        expect(published_event.event_staffs.last.bio).to eq("Custom event bio")
      end

      it "clears the event bio when submitted blank, falling back to the profile bio" do
        staffer.update!(bio: "Profile bio", profile_show_bio: true)
        event_staff = create(:event_staff, event: published_event, person: staffer, bio: "Old event bio")
        sign_in admin
        patch staff_event_path(published_event), params: {
          event: {
            event_staffs_attributes: {
              "0" => { id: event_staff.id, person_id: staffer.id, bio: "" }
            }
          }
        }
        expect(event_staff.reload.bio).to be_nil
        get staff_event_path(published_event)
        expect(response.body).to include("Profile bio")
      end

      it "removes a staff member when _destroy is set" do
        event_staff = create(:event_staff, event: published_event, person: staffer)
        sign_in admin
        expect {
          patch staff_event_path(published_event), params: {
            event: {
              event_staffs_attributes: {
                "0" => { id: event_staff.id, _destroy: "1" }
              }
            }
          }
        }.to change(EventStaff, :count).by(-1)
      end

      it "forbids a non-admin" do
        sign_in user
        patch staff_event_path(published_event), params: {
          event: { event_staffs_attributes: { "0" => { person_id: staffer.id, title: "Staff" } } }
        }
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /index?staffed_by_me" do
      it "returns only events the current user's person staffs" do
        admin_with_person = create(:user, :admin, :with_person)
        staffed = create(:event, :published, title: "Staffed event")
        create(:event, :published, title: "Other event")
        create(:event_staff, event: staffed, person: admin_with_person.person)

        sign_in admin_with_person
        get events_path(staffed_by_me: true)
        expect(response.body).to include("Staffed event")
        expect(response.body).not_to include("Other event")
      end
    end
  end

  describe "GET /show register button for signed-in users" do
    let(:registerable_event) { create(:event, :published) }
    let(:one_click_action) { "/events/#{registerable_event.id}/registrations" }
    let(:form_path) { new_event_public_registration_path(registerable_event) }

    before { sign_in user }

    it "renders a one-click register button when no registration form is linked" do
      get event_url(registerable_event)
      expect(response.body).to include(one_click_action)
      expect(response.body).not_to include(form_path)
    end

    it "routes to the registration form when one is linked" do
      form = create(:form, name: "Registration")
      create(:event_form, event: registerable_event, form: form, role: "registration")
      get event_url(registerable_event)
      expect(response.body).to include(form_path)
    end

    it "renders a one-click button when a form is linked but signed_in_one_click is enabled" do
      form = create(:form, name: "Registration")
      create(:event_form, event: registerable_event, form: form, role: "registration")
      registerable_event.update!(signed_in_one_click_enabled: true)
      get event_url(registerable_event)
      expect(response.body).to include(one_click_action)
      expect(response.body).not_to include(form_path)
    end
  end

  describe "GET /events/:id/bulk_payments" do
    let(:admin) { create(:user, :admin) }
    let(:event) { create(:event, cost_cents: 2500) }
    let(:bulk_form) { create(:form) }
    let!(:event_form) { create(:event_form, event: event, form: bulk_form, role: "bulk_payment") }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: bulk_form, event: event, role: "bulk_payment") }
    let!(:attendees_field) do
      create(:form_field, form: bulk_form, field_identifier: "number_of_attendees", name: "Attendees")
    end

    before { sign_in admin }

    it "shows the submitted amount even when no payment has landed" do
      submission.form_answers.create!(form_field: attendees_field, submitted_answer: "3")

      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("$75")
    end

    it "shows the recorded payment amount when a payment exists" do
      submission.form_answers.create!(form_field: attendees_field, submitted_answer: "3")
      create(:payment, person: payer, form_submission: submission,
             amount_cents: 5000, amount_cents_remaining: 5000)

      get bulk_payments_event_path(event)

      expect(response.body).to include("$50")
    end

    it "renders the targeted submission's row expanded when given an expand param" do
      get bulk_payments_event_path(event, expand: submission.id)

      expect(response.body).to include("id=\"payment-card-#{submission.id}\"")
      # Expanded server-side: the toggle button gets data-dropdown-target="expand"
      # so the dropdown controller clicks it on connect to open the card.
      expect(response.body).to include("data-dropdown-target=\"expand\"")
    end

    it "renders rows collapsed without an expand param" do
      get bulk_payments_event_path(event)

      # Collapsed: the details panel keeps the `hidden` class and this card's chevron is not rotated.
      expect(response.body).to match(/id="payment-details-#{submission.id}"\s+class="hidden/)
      expect(response.body).not_to match(/id="payment-arrow-#{submission.id}"[^>]*rotate-180/)
    end

    it "renders a Profile column with a circle-only profile button for matched attendees" do
      attendee = create(:person, first_name: "Match", last_name: "Attendee", email: "match.attendee@example.com")
      create(:event_registration, event: event, registrant: attendee, status: "registered")
      create(:form_field, form: bulk_form, field_identifier: "bulk_payment_attendees", name: "Attendees list")
      submission.form_answers.create!(
        form_field: bulk_form.form_fields.find_by(field_identifier: "bulk_payment_attendees"),
        submitted_answer: [ { first_name: "Match", last_name: "Attendee", email: "match.attendee@example.com" } ].to_json
      )

      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(">Profile<")
      # Circle-only profile button: a boxed (sky) link to the person holding just
      # the compact h-5 avatar circle.
      expect(response.body).to include(person_path(attendee))
      expect(response.body).to include("bg-sky-100")
      expect(response.body).to include("h-5 w-5")
    end

    it "shows a grey \"Paid\" instead of an orange balance when the registration is fully covered" do
      attendee = create(:person, first_name: "Paid", last_name: "Infull", email: "paid.infull@example.com")
      registration = create(:event_registration, event: event, registrant: attendee, status: "registered")
      create(:form_field, form: bulk_form, field_identifier: "bulk_payment_attendees", name: "Attendees list")
      submission.form_answers.create!(
        form_field: bulk_form.form_fields.find_by(field_identifier: "bulk_payment_attendees"),
        submitted_answer: [ { first_name: "Paid", last_name: "Infull", email: "paid.infull@example.com" } ].to_json
      )
      # Fully cover the $25 registration fee so nothing is owed.
      create(:allocation, source: create(:payment, amount_cents: 2500, amount_cents_remaining: 2500),
             allocatable: registration, amount: 2500)

      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("text-gray-500 whitespace-nowrap\">Paid<")
      expect(response.body).not_to include("$0.00")
    end

    it "lists only registrants who are not yet fully paid in the new-allocation dropdown" do
      # The dropdown only renders when the payment still has an unallocated balance.
      create(:payment, person: payer, form_submission: submission,
             amount_cents: 5000, amount_cents_remaining: 5000)
      unpaid = create(:person, first_name: "Owes", last_name: "Money", email: "owes.money@example.com")
      create(:event_registration, event: event, registrant: unpaid, status: "registered")
      paid = create(:person, first_name: "All", last_name: "Square", email: "all.square@example.com")
      paid_registration = create(:event_registration, event: event, registrant: paid, status: "registered")
      # Fully cover the $25 registration fee so this registrant drops off the list.
      create(:allocation, source: create(:payment, amount_cents: 2500, amount_cents_remaining: 2500),
             allocatable: paid_registration, amount: 2500)

      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Owes Money — owes.money@example.com")
      expect(response.body).not_to include("All Square — all.square@example.com")
    end
  end

  describe "POST /events/:id/allocate_bulk_payment" do
    let(:admin) { create(:user, :admin) }
    let(:event) { create(:event) }
    let(:bulk_form) { create(:form) }
    let!(:event_form) { create(:event_form, event: event, form: bulk_form, role: "bulk_payment") }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: bulk_form, event: event, role: "bulk_payment") }
    let!(:payment) { create(:payment, person: payer, form_submission: submission,
                            amount_cents: 1000, amount_cents_remaining: 1000) }
    let(:registrant) { create(:person) }
    let!(:event_registration) { create(:event_registration, event: event, registrant: registrant) }

    let(:valid_params) do
      { payment_id: payment.id, event_registration_id: event_registration.id, amount_dollars: "5.00" }
    end

    before { sign_in admin }

    it "rejects unauthenticated request" do
      sign_out admin
      post allocate_bulk_payment_event_path(event), params: valid_params
      expect(response).to redirect_to(new_user_session_path)
    end

    it "rejects non-admin request" do
      sign_out admin
      sign_in create(:user)
      post allocate_bulk_payment_event_path(event), params: valid_params
      expect(response).to redirect_to(root_path)
    end

    it "creates an allocation and returns turbo_stream" do
      expect {
        post allocate_bulk_payment_event_path(event), params: valid_params, as: :turbo_stream
      }.to change(Allocation, :count).by(1)

      expect(payment.reload.amount_cents_remaining).to eq(500)
      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("Allocation successful")
    end

    context "when the allocation pays a matched registration in full" do
      let(:event) { create(:event, cost_cents: 500) }
      let(:registrant) { create(:person, email: "match@example.com") }
      let!(:attendees_field) do
        create(:form_field, form: bulk_form, field_identifier: "bulk_payment_attendees", name: "Attendees")
      end

      before do
        submission.form_answers.create!(
          form_field: attendees_field,
          submitted_answer: [ { first_name: registrant.first_name, last_name: registrant.last_name, email: "match@example.com" } ].to_json
        )
      end

      it "re-renders the card with refreshed totals and hides the inline allocate box for that registration" do
        post allocate_bulk_payment_event_path(event),
             params: { payment_id: payment.id, event_registration_id: event_registration.id, amount_dollars: "5.00" },
             as: :turbo_stream

        # The whole card is re-rendered (kept expanded) with the new totals: the
        # registration is now fully paid, so its due button reads "Paid".
        expect(response.body).to include("payment-card-#{submission.id}")
        expect(response.body).to include("rotate-180")
        expect(response.body).to include(">Paid</span>")
        # Payment still has $5 left, so only the bottom "New allocation" form
        # remains — the inline per-row box for the now-paid registration is gone.
        expect(response.body.scan(">Allocate</button>").size).to eq(1)
      end
    end

    it "shows alert when event_registration_id is blank" do
      params = valid_params.merge(event_registration_id: "")
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Please select a registrant")
    end

    it "shows alert when event_registration_id is invalid" do
      params = valid_params.merge(event_registration_id: 999999)
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Please select a registrant")
    end

    it "shows alert when amount is zero" do
      params = valid_params.merge(amount_dollars: "0.00")
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Amount must be greater than $0.00")
    end

    it "shows alert when amount exceeds remaining balance" do
      params = valid_params.merge(amount_dollars: "20.00")
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Amount exceeds remaining balance")
    end

    it "shows alert when event registration is already fully paid" do
      large_payment = create(:payment, person: payer, form_submission: submission,
                             amount_cents: 2000, amount_cents_remaining: 2000)
      create(:allocation, source: large_payment, allocatable: event_registration, amount: 1099)

      params = { payment_id: large_payment.id, event_registration_id: event_registration.id, amount_dollars: "5.00" }
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("already fully paid")
    end
  end

  describe "POST /send_reminder" do
    let!(:registration_one) { create(:event_registration, event: event) }
    let!(:registration_two) { create(:event_registration, event: event) }

    before { sign_in admin }

    it "creates one reminder notification per selected registrant" do
      expect {
        post send_reminder_event_path(event), params: {
          registration_ids: [ registration_one.id, registration_two.id ],
          custom_message: "See you soon!"
        }
      }.to change { Notification.where(kind: "event_registration_reminder").count }.by(2)

      expect(response).to redirect_to(registrants_event_path(event))
    end

    it "sends a single admin FYI summarizing the batch" do
      expect {
        post send_reminder_event_path(event), params: {
          registration_ids: [ registration_one.id, registration_two.id ],
          custom_message: "See you soon!"
        }
      }.to have_enqueued_mail(EventMailer, :event_registration_reminder_fyi).once
    end

    it "stores the custom message and recipient on each notification" do
      post send_reminder_event_path(event), params: {
        registration_ids: [ registration_one.id ],
        custom_message: "See you soon!"
      }

      notification = Notification.find_by(kind: "event_registration_reminder", noticeable: registration_one)
      expect(notification.custom_message).to eq("See you soon!")
      expect(notification.recipient_role).to eq("person")
      expect(notification.recipient_email).to eq(registration_one.registrant.preferred_email)
    end

    it "stores the custom subject on each notification" do
      post send_reminder_event_path(event), params: {
        registration_ids: [ registration_one.id ],
        custom_subject: "Don't miss our event!"
      }

      notification = Notification.find_by(kind: "event_registration_reminder", noticeable: registration_one)
      expect(notification.custom_subject).to eq("Don't miss our event!")
    end

    it "creates no notifications when nothing is selected" do
      expect {
        post send_reminder_event_path(event), params: { registration_ids: [] }
      }.not_to change(Notification, :count)

      expect(response).to redirect_to(preview_reminder_event_path(event, custom_message: "", custom_subject: ""))
    end
  end

  describe "GET /registrants" do
    let!(:registration) { create(:event_registration, event: event) }

    before { sign_in admin }

    it "does not show the registrant's affiliation organization names (moved to the link-organization page)" do
      create(:affiliation, person: registration.registrant,
        organization: create(:organization, name: "Helping Hands Center"),
        title: "Facilitator")

      get registrants_event_path(event)

      expect(response.body).not_to include("Helping Hands Center")
    end
  end
end
