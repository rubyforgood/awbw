require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

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
        expect(response.body).to include("Sunday, June 15")
        expect(response.body).to include("12 pm - 1 pm")
      end

      it "displays start time in Eastern for user with time_zone America/New_York" do
        user_et = create(:user, time_zone: "Eastern Time (US & Canada)")
        sign_in user_et
        get event_url(event_with_fixed_times)

        expect(response).to be_successful
        # 19:00 UTC = 3:00 pm ET (styled format on show page)
        expect(response.body).to include("Sunday, June 15")
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
        # datetime-local sends "YYYY-MM-DDTHH:MM" — interpreted in request's Time.zone (PT)
        # 12:00–13:00 PT (PDT) on 2025-06-15 = 19:00–20:00 UTC
        post events_url, params: { event: {
          title: "PT event",
          description: "desc",
          start_date: "2025-06-15T12:00",
          end_date: "2025-06-15T13:00",
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
          start_date: "2025-06-15T15:00",
          end_date: "2025-06-15T16:00",
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
  end

  describe "PATCH /update" do
    let(:update_params) { { event: { title: "Updated" } } }

    context "as admin" do
      before { sign_in admin }

      it "updates event" do
        patch event_path(event), params: update_params
        expect(event.reload.title).to eq("Updated")
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

  describe "GET /events/:id/manage" do
    let(:person) { create(:person) }
    let!(:registration) { create(:event_registration, event: event, registrant: person) }

    before { sign_in admin }

    context "confirmed column toggle" do
      it "renders the slide toggle for confirmed column" do
        get manage_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('data-controller="column-toggle"')
        expect(response.body).to include("Confirmed")
      end

      it "renders confirmed column header hidden by default" do
        get manage_event_path(event)

        expect(response.body).to include("data-column-toggle-col")
      end

      context "when registrant has a confirmed user" do
        it "shows confirmed check icon" do
          get manage_event_path(event)

          expect(response.body).to include("fa-check-circle")
        end
      end

      context "when registrant has an unconfirmed user with invite sent" do
        let(:person) { create(:person, user: create(:user, :unconfirmed, welcome_instructions_sent_at: 1.day.ago)) }

        it "shows clock icon" do
          get manage_event_path(event)

          expect(response.body).to include("fa-solid fa-clock")
        end
      end

      context "when registrant has an unconfirmed user without invite" do
        let(:person) { create(:person, user: create(:user, :unconfirmed)) }

        it "shows invite button" do
          get manage_event_path(event)

          expect(response.body).to include("Invite")
        end
      end

      context "when registrant has no user" do
        let(:person) { create(:person, user: nil) }

        it "shows create user link" do
          get manage_event_path(event)

          expect(response.body).to include("Create user")
        end
      end
    end

    context "registration form icon" do
      let(:reg_form) { create(:form, :standalone, name: "Registration Form") }

      it "shows green icon when person submitted the current registration form" do
        create(:event_form, event: event, form: reg_form, role: "registration")
        create(:form_submission, person: person, form: reg_form)

        get manage_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('fa-solid fa-file-lines')
      end

      it "shows gray icon when person has not submitted any form" do
        create(:event_form, event: event, form: reg_form, role: "registration")

        get manage_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('fa-regular fa-file-lines')
      end

      it "does not show any form icon when event has no forms" do
        get manage_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('fa-file-lines')
      end
    end
  end

  describe "GET /events/:id/manage with payment and scholarship filters" do
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
      scholarship = create(:scholarship, recipient: pending_scholarship_person, tasks_completed: false, amount_cents: 1_000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 0)
      reg
    end

    before { sign_in admin }

    it "filters to paid-in-full registrants" do
      get manage_event_path(event, payment_status: "paid")
      expect(response.body).to include("Paid Person")
      expect(response.body).to include("Scholar Person")
      expect(response.body).not_to include("Unpaid Person")
    end

    it "filters to not-paid-in-full registrants" do
      get manage_event_path(event, payment_status: "unpaid")
      expect(response.body).to include("Unpaid Person")
      expect(response.body).not_to include("Paid Person")
    end

    it "filters to all scholarship recipients" do
      get manage_event_path(event, scholarship: "yes")
      expect(response.body).to include("Scholar Person")
      expect(response.body).to include("Pending Person")
      expect(response.body).not_to include("Paid Person")
      expect(response.body).not_to include("Unpaid Person")
    end

    it "filters to recipients whose tasks are complete" do
      get manage_event_path(event, scholarship: "complete")
      expect(response.body).to include("Scholar Person")
      expect(response.body).not_to include("Pending Person")
    end

    it "filters to recipients whose tasks are not complete" do
      get manage_event_path(event, scholarship: "incomplete")
      expect(response.body).to include("Pending Person")
      expect(response.body).not_to include("Scholar Person")
    end
  end

  describe "GET /events/:id/manage with state and county filters" do
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
      get manage_event_path(event, state: "CA")
      expect(response.body).to include("Cali Person")
      expect(response.body).not_to include("York Person")
    end

    it "filters registrants by a state-scoped county value" do
      get manage_event_path(event, county: "NY|Kings")
      expect(response.body).to include("York Person")
      expect(response.body).not_to include("Cali Person")
      expect(response.body).not_to include("Caliking Person")
    end

    it "filters registrants by a hyphenated registrant id list" do
      get manage_event_path(event, registrant_ids: ca_person.id.to_s)
      expect(response.body).to include("Cali Person")
      expect(response.body).not_to include("York Person")
    end

    it "filters registrants by sector" do
      sector = create(:sector)
      create(:sectorable_item, sector: sector, sectorable: ca_person)

      get manage_event_path(event, sector: sector.id)
      expect(response.body).to include("Cali Person")
      expect(response.body).not_to include("York Person")
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

      it "renders the payments section with totals for a paid event" do
        create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                            allocatable: registration, amount: 6_000)

        get dashboard_event_path(event)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Registration fees")
        expect(response.body).to include("Cont ed fees")
        expect(response.body).to include("Paid")
        expect(response.body).to include("$60.00")
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
end
