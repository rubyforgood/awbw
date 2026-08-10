require "rails_helper"
require "csv"

RSpec.describe "EventRegistrations", type: :request do
  let(:regular_user) { create(:user, :with_person, email: "john.doe@example.com") }
  let(:admin)        { create(:user, :with_person, super_user: true) }
  let(:other_user)   { create(:user, :with_person) }

  let(:event)        { create(:event, title: "Test Event") }
  let(:new_event)    { create(:event) }

  let!(:existing_registration) { create(:event_registration, event: event, registrant: regular_user.person) }

  # ============================================================
  # ADMIN
  # ============================================================
  context "as an admin" do
    before { sign_in admin }

    describe "GET /event_registrations" do
      it "can access index" do
        get event_registrations_path
        expect(response).to have_http_status(:success)
      end

      it "links to the selected event's dashboard when one is filtered" do
        event.update!(abbreviation: "TAC261")
        get event_registrations_path(event_id: event.id)
        expect(response.body).to include("TAC261 event dashboard")
        expect(response.body).to include(dashboard_event_path(event))
      end

      it "shows no event-dashboard link with no event filtered" do
        get event_registrations_path
        expect(response.body).not_to include("event dashboard")
      end

      it "filters registrations by organization_id" do
        organization = create(:organization)
        matching_reg = create(:event_registration)
        create(:event_registration_organization, event_registration: matching_reg, organization: organization)

        get event_registrations_path(organization_id: organization.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(matching_reg.registrant.name)
        expect(response.body).not_to include(existing_registration.registrant.name)
      end

      it "filters registrations by ce_status" do
        needs_license = create(:event_registration)
        placeholder = create(:professional_license, :placeholder, person: needs_license.registrant)
        create(:continuing_education_registration, event_registration: needs_license, professional_license: placeholder)

        get event_registrations_path(ce_status: "needs_license")
        expect(response).to have_http_status(:success)
        expect(response.body).to include(needs_license.registrant.name)
        expect(response.body).not_to include(existing_registration.registrant.name)
      end

      it "filters registrations by attendance status" do
        no_show = create(:event_registration, status: "no_show")

        get event_registrations_path(attendance_status: "no_show")
        expect(response).to have_http_status(:success)
        expect(response.body).to include(no_show.registrant.name)
        expect(response.body).not_to include(existing_registration.registrant.name)
      end

      it "filters registrations to 'other' outcomes (not attended/partial/no-show)" do
        cancelled = create(:event_registration, status: "cancelled")
        attended = create(:event_registration, status: "attended")

        get event_registrations_path(attendance_status: "other")
        expect(response).to have_http_status(:success)
        expect(response.body).to include(cancelled.registrant.name)
        expect(response.body).to include(existing_registration.registrant.name) # registered
        expect(response.body).not_to include(attended.registrant.name)
      end

      it "filters registrations by event year" do
        this_year = create(:event_registration, event: create(:event, start_date: Date.new(2026, 5, 1)))
        last_year = create(:event_registration, event: create(:event, start_date: Date.new(2025, 5, 1)))

        get event_registrations_path(event_year: 2026)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(this_year.registrant.name)
        expect(response.body).not_to include(last_year.registrant.name)
      end

      it "filters registrations by event type" do
        training_reg = create(:event_registration, event: create(:event, facilitator_training: true))

        get event_registrations_path(event_type: "trainings")
        expect(response).to have_http_status(:success)
        expect(response.body).to include(training_reg.registrant.name)
        expect(response.body).not_to include(existing_registration.registrant.name)
      end

      it "filters registrations by payment status" do
        paid_event = create(:event, cost_cents: 1000)
        paid = create(:event_registration, event: paid_event)
        create(:allocation, source: create(:payment, amount_cents: 1000, amount_cents_remaining: 1000),
                            allocatable: paid, amount: 1000)
        unpaid = create(:event_registration, event: paid_event)

        get event_registrations_path(payment_status: "paid")
        expect(response).to have_http_status(:success)
        expect(response.body).to include(paid.registrant.name)
        expect(response.body).not_to include(unpaid.registrant.name)
      end

      it "filters registrations by funder (org-subsidized vs grant-funded)" do
        org_subsidized = create(:event_registration)
        unfunded = create(:scholarship, recipient: org_subsidized.registrant, amount_cents: 1000)
        create(:allocation, source: unfunded, allocatable: org_subsidized, amount: 1000)
        grant_funded = create(:event_registration)
        funded = create(:scholarship, recipient: grant_funded.registrant, grant: create(:grant), amount_cents: 1000)
        create(:allocation, source: funded, allocatable: grant_funded, amount: 1000)

        get event_registrations_path(funder: "awbw")
        expect(response.body).to include(org_subsidized.registrant.name)
        expect(response.body).not_to include(grant_funded.registrant.name)

        get event_registrations_path(funder: "external")
        expect(response.body).to include(grant_funded.registrant.name)
        expect(response.body).not_to include(org_subsidized.registrant.name)
      end

      it "exports CSV with headers and data only (no captions)" do
        get event_registrations_path, params: { format: :csv }

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".csv")

        rows = CSV.parse(response.body)
        expect(rows.size).to be >= 1
        expect(rows.first).to eq([ "First name", "Last name", "Email", "Phone", "Event", "Status", "Scholarship", "Scholarship completed", "Payment status", "Intends to pay", "Payment total", "CE status", "CE paid", "CE due" ])

        data_rows = rows.drop(1)
        expect(data_rows).not_to be_empty
        person = regular_user.person
        expected_row = [
          person.first_name.to_s,
          person.last_name.to_s,
          person.preferred_email.to_s,
          person.phone_number.to_s,
          event.title.to_s,
          "Registered",
          "No",
          "No",
          "Due",
          "No",
          "",
          "",
          "",
          ""
        ]
        expect(data_rows).to include(expected_row)
      end

      # The CE, scholarship, payment and phone cells each used to query per row;
      # they're preloaded for the CSV only, so the export stays flat.
      it "exports without querying per registration" do
        add_registration = lambda do
          registration = create(:event_registration, event: event, registrant: create(:person))
          ce = create(:continuing_education_registration, event_registration: registration, cost_cents: 5_000)
          create(:allocation, source: create(:payment, amount_cents: 2_000, amount_cents_remaining: 2_000),
                              allocatable: ce, amount: 2_000)
          ContactMethod.create!(contactable: registration.registrant, kind: "phone", value: "555-0100")
        end
        query_count = lambda do
          count = 0
          counter = ->(_name, _start, _finish, _id, payload) { count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/) }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get event_registrations_path(format: :csv) }
          count
        end

        add_registration.call
        get event_registrations_path(format: :csv) # warm up: the first request of a session also loads the signed-in user
        baseline = query_count.call
        3.times { add_registration.call }

        expect(query_count.call).to eq(baseline)
      end

      context "registration form icon" do
        let(:reg_form) { create(:form, :standalone, name: "Registration Form") }
        let(:person) { existing_registration.registrant }

        it "shows green icon when person submitted the current registration form" do
          create(:event_form, event: event, form: reg_form, role: "registration")
          create(:form_submission, person: person, form: reg_form, event: event)

          get event_registrations_path

          expect(response.body).to include("fa-solid fa-file-lines")
        end

        it "shows gray icon when person has not submitted any form" do
          create(:event_form, event: event, form: reg_form, role: "registration")

          get event_registrations_path

          expect(response.body).to include("fa-regular fa-file-lines")
        end

        it "does not show any form icon when event has no forms" do
          get event_registrations_path

          expect(response.body).not_to include("fa-file-lines")
        end
      end

      it "paginates results" do
        additional = create_list(:event_registration, 3)

        get event_registrations_path, params: { number_of_items_per_page: 1 }

        expect(response).to have_http_status(:success)

        first_dom_id = ActionView::RecordIdentifier.dom_id(existing_registration)
        other_dom_id = ActionView::RecordIdentifier.dom_id(additional.first)

        expect(response.body).to include(first_dom_id)
        expect(response.body).not_to include(other_dom_id)
      end
    end

    describe "PATCH /event_registrations/:id/update_onboarding" do
      # Two-day event (day_count == 2) so a single day is a partial attendance.
      let(:two_day_event) { create(:event, start_date: 12.days.from_now, end_date: 13.days.from_now) }
      let(:registration) { create(:event_registration, event: two_day_event, status: "registered") }

      def toggle_day(field, value)
        patch update_onboarding_event_registration_path(registration),
              params: { field: field, value: value },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "flips registered → incomplete_attendance when one day is checked" do
        toggle_day("completed_day_1", "1")
        expect(registration.reload.status).to eq("incomplete_attendance")
      end

      it "flips to attended once both days are checked" do
        registration.update!(completed_day_1: true, status: "incomplete_attendance")
        toggle_day("completed_day_2", "1")
        expect(registration.reload.status).to eq("attended")
      end

      it "rolls back to registered when the last checked day is unchecked" do
        registration.update!(completed_day_1: true, status: "incomplete_attendance")
        toggle_day("completed_day_1", "0")
        expect(registration.reload.status).to eq("registered")
      end

      it "re-renders the attendance badge in the turbo stream when the status changes" do
        toggle_day("completed_day_1", "1")
        expect(response.body).to include("attendance_status_event_registration_#{registration.id}")
      end

      it "does not touch a cancelled registration" do
        registration.update!(status: "cancelled")
        toggle_day("completed_day_1", "1")
        expect(registration.reload.status).to eq("cancelled")
      end
    end

    describe "PATCH /event_registrations/:id/toggle_certificate_issued" do
      let(:registration) { create(:event_registration, event: event) }

      def toggle_certificate(value)
        patch toggle_certificate_issued_event_registration_path(registration),
              params: { value: value },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "marks the registration's certificate issued" do
        toggle_certificate("1")
        expect(registration.reload.certificate_issued?).to be(true)
      end

      it "clears the certificate when unchecked" do
        registration.mark_certificate_sent!
        toggle_certificate("0")
        expect(registration.reload.certificate_issued?).to be(false)
      end

      it "drives the CE certificate for a CE registration, so it stays in sync with the CE edit page" do
        ce = create(:continuing_education_registration, event_registration: registration)

        toggle_certificate("1")
        expect(ce.reload.certificate_sent_at).to be_present

        toggle_certificate("0")
        expect(ce.reload.certificate_sent_at).to be_nil
      end

      it "replaces just the toggled cell in the turbo stream" do
        toggle_certificate("1")
        expect(response.body).to include("certificate_issued_event_registration_#{registration.id}")
      end
    end

    describe "POST /event_registrations" do
      it "creates registration and redirects admin to confirm page" do
        expect {
          post event_registrations_path,
               params: { return_to: "registrants", event_registration: { event_id: event.id, registrant_id: admin.person.id } }
        }.to change(EventRegistration, :count).by(1)

        registration = EventRegistration.last
        expect(response).to redirect_to(confirm_event_registration_path(registration, return_to: "registrants"))
      end

      it "handles a concurrent duplicate insert without raising" do
        # Simulate the race where two requests both pass the uniqueness
        # validation before either inserts, so the DB unique index rejects the
        # second insert. The controller must rescue this and not 500.
        allow_any_instance_of(EventRegistration).to receive(:save).and_raise(
          ActiveRecord::RecordNotUnique.new("Duplicate entry")
        )

        expect {
          post event_registrations_path,
               params: { return_to: "registrants", event_registration: { event_id: event.id, registrant_id: regular_user.person.id } }
        }.not_to change(EventRegistration, :count)

        expect(response).to redirect_to(registrants_event_path(event))
        expect(flash[:alert]).to be_present
      end
    end

    describe "GET /event_registrations/:id/confirm" do
      it "renders the confirm page" do
        get confirm_event_registration_path(existing_registration, return_to: "registrants")
        expect(response).to have_http_status(:success)
      end
    end

    describe "POST /event_registrations/:id/process_confirm" do
      it "redirects to registrants page when return_to is registrants" do
        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants" }

        expect(response).to redirect_to(registrants_event_path(existing_registration.event))
        expect(flash[:notice]).to eq("Registration created.")
      end

      it "redirects to ticket page when return_to is ticket" do
        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "ticket" }

        expect(response).to redirect_to(registration_ticket_path(existing_registration.slug))
      end

      it "sends only confirmation email when selected alone" do
        allow(NotificationServices::CreateNotification).to receive(:call)

        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants", send_confirmation_email: "1" }

        expect(flash[:notice]).to include("Registration confirmation email sent")
        expect(flash[:notice]).not_to include("Admin notification")
      end

      it "sends only admin FYI when selected alone" do
        allow(NotificationServices::CreateNotification).to receive(:call)

        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants", send_admin_fyi: "1" }

        expect(flash[:notice]).to include("Admin notification email sent")
        expect(flash[:notice]).not_to include("Registration confirmation")
      end

      it "sends both emails when both selected" do
        allow(NotificationServices::CreateNotification).to receive(:call)

        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants", send_confirmation_email: "1", send_admin_fyi: "1" }

        expect(flash[:notice]).to include("Registration confirmation email sent")
        expect(flash[:notice]).to include("Admin notification email sent")
      end

      it "creates user account when selected" do
        person = existing_registration.registrant
        person.user.destroy!
        person.update!(email: "newuser@example.com")
        person.reload

        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants", create_user: "1" }

        expect(flash[:notice]).to include("User account created")
        expect(person.reload.user).to be_present
      end

      it "creates user and sends invite when both selected" do
        person = existing_registration.registrant
        person.user.destroy!
        person.update!(email: "invited@example.com")
        person.reload

        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants", create_user: "1", send_invite: "1" }

        expect(flash[:notice]).to include("User account created")
        expect(flash[:notice]).to include("System invite sent")
      end

      it "skips with no actions when nothing selected" do
        post process_confirm_event_registration_path(existing_registration),
             params: { return_to: "registrants" }

        expect(flash[:notice]).to eq("Registration created.")
      end
    end

    describe "GET /event_registrations/:id/edit" do
      it "renders the expected payment method as an editable select with the registrant's answer selected" do
        existing_registration.update!(expected_payment_method: "Check")

        get edit_event_registration_path(existing_registration)

        expect(response.body).to include("Expected payment method")
        expect(response.body).to include("name=\"event_registration[expected_payment_method]\"")
        expect(response.body).to include("<option selected=\"selected\" value=\"Check\">Check</option>")
      end

      it "shows a Delete button for a deletable registration" do
        get edit_event_registration_path(existing_registration)

        expect(response.body).to include("fa-trash-can")
        expect(response.body).not_to include("reverted payments still count")
      end

      it "points Cancel at the event's registrants roster by default" do
        get edit_event_registration_path(existing_registration)

        cancel_href = Capybara.string(response.body).find_link("Cancel")[:href]
        expect(cancel_href).to start_with(registrants_event_path(existing_registration.event))
      end

      it "points Cancel at the registrations index only when the admin came from it" do
        get edit_event_registration_path(existing_registration, return_to: "index")

        cancel_href = Capybara.string(response.body).find_link("Cancel")[:href]
        expect(cancel_href).to eq(event_registrations_path)
      end


      it "shows the scholarship agreement status on the scholarship card" do
        scholarship = Scholarship.new(recipient: existing_registration.registrant, amount_cents: 1_000)
        scholarship.build_allocation(allocatable: existing_registration, amount: 1_000)
        scholarship.save!

        get edit_event_registration_path(existing_registration)
        expect(response.body).to include("Agreement pending")

        scholarship.update!(agreement_signed: true)
        get edit_event_registration_path(existing_registration)
        expect(response.body).to include("Agreement signed")
        expect(response.body).not_to include("Agreement pending")
      end

      it "hides Delete and explains why for a registration with payment records" do
        payment = create(:payment, person: regular_user.person, amount_cents: 1000, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: existing_registration, amount: 1000)

        get edit_event_registration_path(existing_registration)

        expect(response.body).not_to include("fa-trash-can")
        expect(response.body).to include("financial records")
        expect(response.body).to include("reverted payments still count")
      end
    end

    describe "PATCH /event_registrations/:id" do
      it "can update registration" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { event_id: new_event.id } }

        # No explicit return_to: admins land back on the management roster,
        # scrolled to and highlighting the row they just edited, not the public
        # registration show.
        expect(response).to redirect_to(
          registrants_event_path(new_event, anchor: "registrant-row-#{existing_registration.id}", highlight: existing_registration.id)
        )
        expect(existing_registration.reload.event_id).to eq(new_event.id)
      end

      it "sets the shout-out flag and stores the shout-out text on the registrant" do
        patch event_registration_path(existing_registration),
              params: { event_registration: {
                shoutout: "1",
                registrant_attributes: { id: existing_registration.registrant_id, shoutout_text: "Grateful to bring art to survivors." }
              } }

        expect(existing_registration.reload.shoutout).to be(true)
        expect(existing_registration.registrant.reload.shoutout_text).to eq("Grateful to bring art to survivors.")
      end

      it "returns to the recipients page shout-outs section when return_to is recipients" do
        patch event_registration_path(existing_registration),
              params: { return_to: "recipients", event_registration: { shoutout: "1" } }

        expect(response).to redirect_to(recipients_event_path(existing_registration.event, anchor: "shout-outs"))
      end

      it "records an admin-set expected payment method even when the form was never filled out" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { expected_payment_method: "Check" } }

        expect(existing_registration.reload.expected_payment_method).to eq("Check")
      end

      it "clears the expected payment method when set back to not specified" do
        existing_registration.update!(expected_payment_method: "Check")

        patch event_registration_path(existing_registration),
              params: { event_registration: { expected_payment_method: "" } }

        expect(existing_registration.reload.expected_payment_method).to be_blank
      end

      it "flags that someone else will pay when the toggle is on" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { someone_else_will_pay: "1" } }

        expect(existing_registration.reload.someone_else_will_pay).to be(true)
      end
    end

    describe "PATCH /event_registrations/:id scholarship handling" do
      def link_scholarship(registration, amount_cents:, tasks_completed: false)
        scholarship = Scholarship.new(recipient: registration.registrant, amount_cents: amount_cents, tasks_completed: tasks_completed)
        scholarship.build_allocation(allocatable: registration, amount: amount_cents)
        scholarship.save!
        scholarship
      end

      def unrequest(registration)
        patch event_registration_path(registration),
              params: { event_registration: { scholarship_requested: "0" } }
      end

      it "never creates a scholarship from the requested checkbox" do
        expect {
          patch event_registration_path(existing_registration),
                params: { event_registration: { scholarship_requested: "1" } }
        }.not_to change(Scholarship, :count)

        expect(existing_registration.reload.scholarship_requested).to be(true)
      end

      it "keeps a funded scholarship when unrequested" do
        existing_registration.update!(scholarship_requested: true)
        link_scholarship(existing_registration, amount_cents: 1000)

        expect { unrequest(existing_registration) }
          .not_to change { existing_registration.scholarships.count }
      end

      it "zeroes a funded scholarship when the status is set to cancelled" do
        scholarship = link_scholarship(existing_registration, amount_cents: 1000)

        patch event_registration_path(existing_registration),
              params: { event_registration: { status: "cancelled" } }

        expect(existing_registration.reload.status).to eq("cancelled")
        expect(scholarship.reload.amount_cents).to eq(0)
      end
    end

    describe "PATCH /event_registrations/:id logging a notification" do
      it "creates a manual notification log from nested attributes" do
        expect {
          patch event_registration_path(existing_registration), params: {
            event_registration: {
              notifications_attributes: { "0" => { channel: "phone", email_subject: "Left a voicemail" } }
            }
          }
        }.to change { existing_registration.notifications.count }.by(1)

        notification = existing_registration.notifications.order(:created_at).last
        expect(notification.channel).to eq("phone")
        expect(notification.kind).to eq("manual_log")
        expect(notification.email_subject).to eq("Left a voicemail")
        expect(notification.recipient_email).to eq(existing_registration.registrant.preferred_email)
      end

      it "ignores a blank notification with no note" do
        expect {
          patch event_registration_path(existing_registration), params: {
            event_registration: {
              notifications_attributes: { "0" => { channel: "email", email_subject: "" } }
            }
          }
        }.not_to change(Notification, :count)
      end

      it "edits an existing logged notification in place" do
        note = create(:notification, noticeable: existing_registration,
                                     recipient_email: existing_registration.registrant.preferred_email,
                                     channel: "phone", email_subject: "Left a voicemail",
                                     kind: "manual_log", recipient_role: "person", notification_type: 0)

        patch event_registration_path(existing_registration), params: {
          event_registration: {
            notifications_attributes: { "0" => { id: note.id, channel: "email", email_subject: "Sent a reminder" } }
          }
        }

        note.reload
        expect(note.channel).to eq("email")
        expect(note.email_subject).to eq("Sent a reminder")
      end
    end

    describe "DELETE /event_registrations/:id" do
      it "can delete registration" do
        expect {
          delete event_registration_path(existing_registration)
        }.to change(EventRegistration, :count).by(-1)
      end

      it "refuses to delete a registration with payments on record" do
        payment = create(:payment, person: regular_user.person, amount_cents: 1000, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: existing_registration, amount: 1000)

        expect {
          delete event_registration_path(existing_registration)
        }.not_to change(EventRegistration, :count)

        expect(flash[:alert]).to include("can't be deleted")
      end

      it "refuses to delete a registration whose CE registration has payments" do
        ce = create(:continuing_education_registration, event_registration: existing_registration, cost_cents: 12_000)
        create(:allocation, source: create(:payment, amount_cents: 12_000, amount_cents_remaining: 12_000),
                            allocatable: ce, amount: 12_000)

        expect {
          delete event_registration_path(existing_registration)
        }.not_to change(EventRegistration, :count)

        expect(flash[:alert]).to match(/has payments/)
      end
    end

    describe "organization linking" do
      let(:organization) { create(:organization, name: "Helping Hands") }

      describe "GET /event_registrations/:id/link_organization" do
        before do
          create(:event_registration_organization, event_registration: existing_registration, organization: organization)
        end

        # Records what the registrant "typed on the form" so the editor can show
        # the submission and compare its position to an existing affiliation title.
        def submit_form(org_name: nil, position: nil)
          reg_form = Form.find_by(name: "Reg form") || create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form) unless event.registration_form
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          {  "agency_name" => org_name, "agency_position" => position }.each do |identifier, value|
            next if value.nil?
            field = reg_form.form_fields.find_by(field_identifier: identifier) ||
              create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end
          submission
        end

        # Whether the <details> section whose text contains `heading` is expanded.
        def details_open?(body, heading)
          element = Nokogiri::HTML(body).css("details").find { |d| d.text.include?(heading) }
          element&.key?("open")
        end

        it "shows 'No other affiliations on record' when the person has none" do
          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("No other affiliations on record")
        end

        it "flags a persistent discrepancy on a linked org whose saved profile differs from the submission" do
          organization.update!(name: "Acme", agency_type: "For-profit")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_name" => "Acme", "agency_type" => "Government agency" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Form answers differ from this organization")
          expect(response.body).to include("Government agency")
          expect(response.body).to include("For-profit")
        end

        it "does not flag the submitted answers against a second org the registrant never named" do
          organization.update!(name: "Acme", agency_type: "For-profit")
          other = create(:organization, name: "Zebra Center", agency_type: "School district")
          create(:event_registration_organization, event_registration: existing_registration, organization: other)
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_name" => "Acme", "agency_type" => "Government agency" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          get link_organization_event_registration_path(existing_registration)

          # Only the linked-org cards carry an Unlink button, so this skips the
          # submission section above, which also names the submitted org.
          cards = Nokogiri::HTML(response.body).css("li").select { |li| li.text.include?("Unlink") }
          expect(cards.find { |li| li.text.include?("Zebra Center") }.text).not_to include("Government agency")
          expect(cards.find { |li| li.text.include?("Acme") }.text).to include("Government agency")
        end

        it "flags an address discrepancy on a linked org whose saved address differs from the submission" do
          organization.update!(name: "Acme")
          create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_name" => "Acme", "agency_street" => "1 Main St", "agency_city" => "Austin", "agency_state" => "TX" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Address – street")
          expect(response.body).to include("1 Main St")
          expect(response.body).to include("5 Oak Ave")
        end

        it "shows the affiliation pill inline on the linked org, noting it has no dates" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Counselor (no dates)")
          expect(response.body).not_to include("Counselor (no dates) — inactive")
        end

        it "links the linked-org card to the person's edit-affiliations section, returning here on save" do
          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include(edit_person_path(regular_user.person))
          expect(response.body).to include("return_to=registration_link")
          expect(response.body).to include("event_registration_id=#{existing_registration.id}")
        end

        it "shows the start date as '(since Month YYYY)' when there is no end date" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor", start_date: Date.new(2024, 3, 1))

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Counselor (since March 2024)")
        end

        it "shows the date range in parens when the affiliation has an end date" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor", start_date: Date.new(2024, 3, 1), end_date: Date.new(2025, 6, 1))

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Counselor (March 2024 – June 2025)")
        end

        it "renders a non-facilitator affiliation title as a non-editable pill" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Counselor")
          expect(response.body).not_to include('name="affiliation[title]"')
        end

        it "links to the registrant's edit-affiliations section using their name, returning here on save" do
          person = regular_user.person

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Edit #{person.first_name.presence || person.full_name}'s affiliations")
          expect(response.body).to include(edit_person_path(person))
          expect(response.body).to include("#affiliations")
          expect(response.body).to include("return_to=registration_link")
        end

        it "warns on Unlink that it removes the org but keeps the affiliation" do
          get link_organization_event_registration_path(existing_registration)

          confirm = Nokogiri::HTML(response.body).css("form[data-turbo-confirm]").map { |f| f["data-turbo-confirm"] }.join
          expect(confirm).to include("will NOT delete")
          expect(confirm).to include("Affiliation")
          expect(confirm).to include("edit the Person record")
        end

        it "lists affiliations for non-linked orgs under the registrant's other affiliations" do
          other_org = create(:organization, name: "Unlinked Org Co")
          create(:affiliation, person: regular_user.person, organization: other_org, title: "Board Member")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("other affiliations")
          expect(response.body).to include(regular_user.person.first_name)
          expect(response.body).to include("Unlinked Org Co")
          expect(response.body).to include("Board Member")
        end

        it "shows 'Facilitator' for an active facilitator affiliation" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Facilitator")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Facilitator")
          expect(response.body).not_to include("Facilitator (no dates) — inactive")
        end

        it "shows a facilitator affiliation as inactive once it has ended" do
          create(:affiliation, person: regular_user.person, organization: organization,
                               title: "Facilitator", end_date: 1.month.ago.to_date)

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Facilitator")
          expect(response.body).to include("inactive")
        end

        it "does not show a title-comparison badge when the affiliation title matches the submitted position" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")
          submit_form(org_name: organization.name, position: "Counselor")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).not_to include("Title differs from form")
        end

        it "does not show a title-comparison badge when a facilitator affiliation matches the submitted 'Facilitator' position" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Facilitator")
          submit_form(org_name: organization.name, position: "Facilitator")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).not_to include("Title differs from form")
        end

        it "shows 'Title differs from form' when the affiliation title differs from the submitted position" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")
          submit_form(org_name: organization.name, position: "Director")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Title differs from form")
          expect(response.body).to include("Director")
        end

        it "renders the submitted form values" do
          submit_form(org_name: "Typed Agency", position: "Volunteer")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Typed Agency")
          expect(response.body).to include("Volunteer")
        end

        it "links the registration form submission to the public form view" do
          submission = submit_form(org_name: "Typed Agency")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include(event_registrant_submissions_path(event, person_id: existing_registration.registrant_id))
          expect(response.body).to include("form_submission_id=#{submission.id}")
        end

        it "lists each registration-form submission with its own view link" do
          reg_form = Form.find_by(name: "Reg form") || create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form) unless event.registration_form
          field = reg_form.form_fields.find_by(field_identifier: "agency_name") ||
            create(:form_field, form: reg_form, field_identifier: "agency_name")
          sub1 = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: sub1, form_field: field, submitted_answer: "First Org")
          sub2 = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: sub2, form_field: field, submitted_answer: "Second Org")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("First Org")
          expect(response.body).to include("Second Org")
          expect(response.body).to include("form_submission_id=#{sub1.id}")
          expect(response.body).to include("form_submission_id=#{sub2.id}")
        end

        it "shows a Create and link row for each distinct submitted org not in the database" do
          reg_form = Form.find_by(name: "Reg form") || create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form) unless event.registration_form
          field = reg_form.form_fields.find_by(field_identifier: "agency_name") ||
            create(:form_field, form: reg_form, field_identifier: "agency_name")
          sub1 = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: sub1, form_field: field, submitted_answer: "Alpha Agency")
          sub2 = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: sub2, form_field: field, submitted_answer: "Beta Agency")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Alpha Agency")
          expect(response.body).to include("Beta Agency")
          expect(response.body.scan(%r{name="organization_name"}).size).to eq(2)
        end

        it "says no registration form was submitted when the person has no submission" do
          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("No registration form was submitted")
        end

        it "says no organization was submitted when the form was submitted without one" do
          submit_form

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("No organization was submitted on the")
          expect(response.body).not_to include("No registration form was submitted")
        end

        it "shows a 'Pending' badge next to the submitted org when nothing is linked" do
          existing_registration.event_registration_organizations.destroy_all
          submit_form(org_name: "Riverside Healing Arts Collective")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Riverside Healing Arts Collective")
          expect(response.body).to include(">Pending<")
        end

        it "does not show the 'Pending' badge once an organization is linked" do
          submit_form(org_name: "Riverside Healing Arts Collective")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).not_to include(">Pending<")
        end

        it "shows 'Create org & link' when the submitted org has no existing match" do
          submit_form(org_name: "Brand New Unlisted Org")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include(create_organization_event_registration_path(existing_registration))
        end

        it "hides 'Create org & link' when an org with the submitted name already exists" do
          create(:organization, name: "Already Exists Org")
          submit_form(org_name: "Already Exists Org")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).not_to include(create_organization_event_registration_path(existing_registration))
        end

        context "section collapse state" do
          it "expands the form submission section when nothing was submitted" do
            get link_organization_event_registration_path(existing_registration)

            expect(details_open?(response.body, "Registration form submission")).to be true
          end

          it "expands the form submission section when the submitted org has no match" do
            submit_form(org_name: "Nonexistent Agency XYZ")

            get link_organization_event_registration_path(existing_registration)

            expect(details_open?(response.body, "Registration form submission")).to be true
          end

          it "keeps the form submission section expanded even when the submitted org already exists" do
            submit_form(org_name: organization.name)

            get link_organization_event_registration_path(existing_registration)

            expect(details_open?(response.body, "Registration form submission")).to be true
          end

          it "expands the other-affiliations section when there are none" do
            get link_organization_event_registration_path(existing_registration)

            expect(details_open?(response.body, "other affiliations")).to be true
          end

          it "keeps the other-affiliations section expanded when the person has other affiliations" do
            create(:affiliation, person: regular_user.person, organization: create(:organization, name: "Unlinked Co"), title: "Member")

            get link_organization_event_registration_path(existing_registration)

            expect(details_open?(response.body, "other affiliations")).to be true
          end
        end
      end

      describe "POST /event_registrations/:id/select_organization" do
        it "links the org to the registration and the person, then returns to the edit page" do
          expect {
            post select_organization_event_registration_path(existing_registration),
              params: { organization_id: organization.id }
          }.to change { existing_registration.organizations.count }.by(1)
            .and change { regular_user.person.organizations.count }.by(1)

          expect(response).to redirect_to(link_organization_event_registration_path(existing_registration))
        end

        it "creates a job affiliation and a facilitator affiliation from the submitted position" do
          reg_form = create(:form, name: "Reg form")
          field = create(:form_field, form: reg_form, field_identifier: EventRegistrationServices::PublicRegistration::ORGANIZATION_POSITION_IDENTIFIER)
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Counselor")

          post select_organization_event_registration_path(existing_registration),
            params: { organization_id: organization.id }

          expect(regular_user.person.affiliations.where(organization: organization).pluck(:title))
            .to contain_exactly("Counselor", "Facilitator")
        end

        it "creates a facilitator affiliation even when no position was submitted" do
          post select_organization_event_registration_path(existing_registration),
            params: { organization_id: organization.id }

          expect(regular_user.person.affiliations.where(organization: organization).pluck(:title))
            .to contain_exactly("Facilitator")
        end

        it "builds the org address from the submission and links the affiliations to it" do
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_street" => "1 Main St", "agency_city" => "Austin", "agency_state" => "TX", "agency_zip" => "78701", "agency_country" => "USA" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration),
            params: { organization_id: organization.id }

          address = organization.addresses.find_by(city: "Austin")
          expect(address).to be_present
          expect(address.country).to eq("USA")
          expect(regular_user.person.affiliations.where(organization: organization).map(&:organization_address))
            .to all(eq(address))
        end

        it "links the affiliation to the org's sole address when the submission carried none" do
          address = create(:address, addressable: organization, city: "Austin", state: "TX")

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(regular_user.person.affiliations.where(organization: organization).map(&:organization_address))
            .to all(eq(address))
        end

        it "fills the org's blank type and website from the submission and says so" do
          organization.update!(agency_type: nil, website_url: nil)
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_website" => "helpinghands.org", "agency_type" => "501c3/nonprofit" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(organization.reload.website_url).to include("helpinghands.org")
          expect(organization.agency_type).to eq("501c3/nonprofit")
          expect(flash[:notice]).to include("Saved from the form").and include("type").and include("website")
        end

        # The flash is gone by the next page load, so what the form changed on an
        # org that already existed is recorded on the link itself.
        it "records what the form filled on the link, and shows it on the page afterwards" do
          organization.update!(agency_type: nil, website_url: nil)
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_website" => "helpinghands.org", "agency_city" => "Austin", "agency_state" => "TX" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          link = existing_registration.event_registration_organizations.find_by(organization: organization)
          expect(link.form_filled_labels).to contain_exactly("website", "work address in Austin")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Filled from this registration's form")
            .and include("website and work address in Austin")
        end

        it "does not seed or report another org's answers when linking an extra organization" do
          create(:event_registration_organization, event_registration: existing_registration, organization: organization)
          other = create(:organization, name: "Zebra Center", website_url: nil, agency_type: nil)
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_name" => "Helping Hands", "agency_website" => "helpinghands.org" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: other.id }

          expect(other.reload.website_url).to be_nil
          expect(flash[:warning]).to be_nil
        end

        # The registrant typed that title about the org they named, not about an
        # unrelated one an admin linked by hand.
        it "does not apply the submitted position to an extra organization the submission doesn't name" do
          create(:event_registration_organization, event_registration: existing_registration, organization: organization)
          other = create(:organization, name: "Zebra Center")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_name" => "Helping Hands", "agency_position" => "Counselor" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: other.id }

          expect(regular_user.person.affiliations.where(organization: other).pluck(:title)).to contain_exactly("Facilitator")
        end

        it "keeps curated type/website and warns about the discrepancy" do
          organization.update!(agency_type: "For-profit", website_url: "https://curated.org")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_website" => "https://other.org", "agency_type" => "Government agency" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(organization.reload.agency_type).to eq("For-profit")
          expect(organization.website_url).to eq("https://curated.org")
          expect(flash[:warning]).to include("were not applied").and include("Government agency").and include("For-profit")
        end

        it "escapes a submitted answer before putting it in the flash warning" do
          organization.update!(website_url: "https://curated.org")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          field = create(:form_field, form: reg_form, field_identifier: "agency_website")
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "<img src=x onerror=alert(1)>")

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }
          follow_redirect!

          # Flash messages are rendered with html_safe, so the raw tag must never survive.
          expect(response.body).not_to include("<img src=x onerror=alert(1)>")
          expect(flash.now[:warning].to_s).to include("&lt;img src=x")
        end

        it "links without a 500 when the submitted address has no ZIP" do
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_city" => "Austin", "agency_state" => "TX" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(response).to redirect_to(link_organization_event_registration_path(existing_registration))
          expect(organization.addresses.find_by(city: "Austin")).to have_attributes(street_address: "", zip_code: "")
        end

        it "names the city of the work address it created" do
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_street" => "1 Main St", "agency_city" => "Austin", "agency_state" => "TX", "agency_zip" => "78701" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(flash[:notice]).to include("Saved from the form: work address in Austin")
        end

        it "does not claim the work address was saved when the submission changed nothing on it" do
          create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78701", country: "USA")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_street" => "1 Main St", "agency_city" => "Austin", "agency_state" => "TX", "agency_zip" => "78701" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(flash[:notice]).not_to include("work address")
          expect(flash[:warning]).to include("Address – street")
        end

        it "reports only the address fields it actually filled" do
          create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "", country: "USA")
          reg_form = create(:form, name: "Reg form")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          { "agency_street" => "1 Main St", "agency_city" => "Austin", "agency_state" => "TX", "agency_zip" => "78701" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post select_organization_event_registration_path(existing_registration), params: { organization_id: organization.id }

          expect(flash[:notice]).to include("Saved from the form: ZIP on the Austin work address")
        end
      end

      describe "POST /event_registrations/:id/create_organization" do
        it "creates an org from the submitted name and links it" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Brand New Org")

          expect {
            post create_organization_event_registration_path(existing_registration)
          }.to change(Organization, :count).by(1)

          expect(existing_registration.organizations.pluck(:name)).to include("Brand New Org")
          expect(response).to redirect_to(link_organization_event_registration_path(existing_registration))
        end

        it "creates a job affiliation and a facilitator affiliation for the new org from the submitted position" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          name_field = create(:form_field, form: reg_form, field_identifier: EventRegistrationServices::PublicRegistration::ORGANIZATION_NAME_IDENTIFIER)
          position_field = create(:form_field, form: reg_form, field_identifier: EventRegistrationServices::PublicRegistration::ORGANIZATION_POSITION_IDENTIFIER)
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: name_field, submitted_answer: "Brand New Org")
          create(:form_answer, form_submission: submission, form_field: position_field, submitted_answer: "Counselor")

          post create_organization_event_registration_path(existing_registration)

          organization = Organization.find_by(name: "Brand New Org")
          expect(regular_user.person.affiliations.where(organization: organization).pluck(:title))
            .to contain_exactly("Counselor", "Facilitator")
        end

        it "builds the new org's address from the submission and links the affiliations to it" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          name_field = create(:form_field, form: reg_form, field_identifier: EventRegistrationServices::PublicRegistration::ORGANIZATION_NAME_IDENTIFIER)
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: name_field, submitted_answer: "Brand New Org")
          { "agency_street" => "1 Main St", "agency_city" => "Austin", "agency_state" => "TX", "agency_zip" => "78701" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post create_organization_event_registration_path(existing_registration)

          organization = Organization.find_by(name: "Brand New Org")
          address = organization.addresses.find_by(city: "Austin")
          expect(address).to be_present
          expect(regular_user.person.affiliations.where(organization: organization).map(&:organization_address))
            .to all(eq(address))
        end

        it "populates the new org's website and type from the submission" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          name_field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: name_field, submitted_answer: "Brand New Org")
          { "agency_website" => "helpinghands.org", "agency_type" => "501c3/nonprofit" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post create_organization_event_registration_path(existing_registration)

          organization = Organization.find_by(name: "Brand New Org")
          expect(organization.website_url).to include("helpinghands.org")
          expect(organization.agency_type).to eq("501c3/nonprofit")
        end

        it "links an existing org instead of creating a duplicate" do
          existing = create(:organization, name: "Existing Org")
          reg_form = create(:form, name: "Reg form")
          field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Existing Org")

          expect {
            post create_organization_event_registration_path(existing_registration)
          }.not_to change(Organization, :count)

          expect(existing_registration.organizations).to include(existing)
        end

        it "fills a blank website and type on an existing org from the submission" do
          existing = create(:organization, name: "Existing Org", website_url: nil, agency_type: nil)
          reg_form = create(:form, name: "Reg form")
          name_field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: name_field, submitted_answer: "Existing Org")
          { "agency_website" => "helpinghands.org", "agency_type" => "Government agency" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post create_organization_event_registration_path(existing_registration)

          expect(existing.reload.website_url).to include("helpinghands.org")
          expect(existing.agency_type).to eq("Government agency")
          expect(existing_registration.event_registration_organizations.find_by(organization: existing).form_filled_labels)
            .to contain_exactly("website", "type")
        end

        # Everything on an org we just created came from the form, so there is
        # nothing to flag as changed on it.
        it "records no form fills on an org it created from the submission" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          name_field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: name_field, submitted_answer: "Brand New Org")
          field = create(:form_field, form: reg_form, field_identifier: "agency_website")
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "brandnew.org")

          post create_organization_event_registration_path(existing_registration)

          organization = Organization.find_by(name: "Brand New Org")
          expect(organization.website_url).to include("brandnew.org")
          expect(existing_registration.event_registration_organizations.find_by(organization: organization).form_filled_labels).to be_empty
        end

        it "does not overwrite an existing org's curated website and type" do
          existing = create(:organization, name: "Existing Org", website_url: "https://curated.org", agency_type: "For-profit")
          reg_form = create(:form, name: "Reg form")
          name_field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: name_field, submitted_answer: "Existing Org")
          { "agency_website" => "helpinghands.org", "agency_type" => "Government agency" }.each do |identifier, value|
            field = create(:form_field, form: reg_form, field_identifier: identifier)
            create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
          end

          post create_organization_event_registration_path(existing_registration)

          expect(existing.reload.website_url).to eq("https://curated.org")
          expect(existing.agency_type).to eq("For-profit")
        end

        it "does nothing when no organization name was submitted" do
          expect {
            post create_organization_event_registration_path(existing_registration)
          }.not_to change(Organization, :count)

          expect(existing_registration.organizations).to be_empty
          expect(response).to redirect_to(link_organization_event_registration_path(existing_registration))
          expect(flash[:alert]).to be_present
        end

        it "creates the specific submitted org named in the request" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          sub1 = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: sub1, form_field: field, submitted_answer: "Alpha Agency")
          sub2 = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: sub2, form_field: field, submitted_answer: "Beta Agency")

          post create_organization_event_registration_path(existing_registration), params: { organization_name: "Beta Agency" }

          expect(existing_registration.organizations.pluck(:name)).to include("Beta Agency")
          expect(existing_registration.organizations.pluck(:name)).not_to include("Alpha Agency")
        end

        it "rejects creating an org name the registrant didn't submit" do
          create(:organization_status, name: "Active")
          reg_form = create(:form, name: "Reg form")
          field = create(:form_field, form: reg_form, field_identifier: "agency_name")
          create(:event_form, :registration, event: event, form: reg_form)
          submission = create(:form_submission, person: regular_user.person, form: reg_form)
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Alpha Agency")

          expect {
            post create_organization_event_registration_path(existing_registration), params: { organization_name: "Made Up Org" }
          }.not_to change(Organization, :count)

          expect(flash[:alert]).to be_present
        end
      end

      describe "DELETE /event_registrations/:id/unlink_organization" do
        before do
          create(:event_registration_organization, event_registration: existing_registration, organization: organization)
          create(:affiliation, person: regular_user.person, organization: organization)
        end

        it "removes only the registration link, leaving the person's affiliation intact" do
          expect {
            delete unlink_organization_event_registration_path(existing_registration),
              params: { organization_id: organization.id }
          }.to change { existing_registration.organizations.count }.by(-1)

          expect(regular_user.person.affiliations.where(organization: organization)).to exist
          expect(response).to redirect_to(link_organization_event_registration_path(existing_registration))
        end
      end
    end
  end

  # ============================================================
  # REGULAR USER
  # ============================================================
  context "as a regular user" do
    let(:event) { create(:event) }

    before do
      sign_in regular_user
    end

    describe "GET /event_registrations" do
      it "redirects to root" do
        get event_registrations_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /event_registrations/:id (admin-only show)" do
      it "redirects to root (unauthorized)" do
        get event_registration_path(existing_registration)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /event_registrations/:id/toggle_certificate_issued" do
      it "is forbidden for the registrant themselves" do
        patch toggle_certificate_issued_event_registration_path(existing_registration), params: { value: "1" }
        expect(response).to redirect_to(root_path)
        expect(existing_registration.reload.certificate_issued?).to be(false)
      end
    end

    describe "POST /event_registrations" do
      context "when no registration exists yet" do
        it "creates a new EventRegistration" do
          expect {
            post event_registrations_path,
                 params: {
                   event_registration: {
                     event_id: new_event.id,
                     registrant_id: regular_user.person.id
                   }
                 }
          }.to change(EventRegistration, :count).by(1)
        end
      end

      context "when a registration already exists" do
        it "does not create a duplicate registration" do
          expect {
            post event_registrations_path,
                 params: {
                   event_registration: {
                     event_id: event.id,
                     registrant_id: regular_user.person.id
                   }
                 }
          }.not_to change(EventRegistration, :count)

          expect(response).to redirect_to(event_registrations_path)
          expect(flash[:alert]).to be_present
        end
      end

      context "with invalid parameters" do
        it "does not create a registration" do
          expect {
            post event_registrations_path,
                 params: { event_registration: { event_id: nil } }
          }.not_to change(EventRegistration, :count)
        end
      end
    end

    describe "GET /event_registrations/:id/confirm" do
      it "redirects to root (unauthorized)" do
        get confirm_event_registration_path(existing_registration)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /event_registrations/:id/process_confirm" do
      it "redirects to root (unauthorized)" do
        post process_confirm_event_registration_path(existing_registration)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /event_registrations/:id" do
      it "can update attendance status" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { status: "cancelled" } }

        expect(existing_registration.reload.status).to eq("cancelled")
        expect(response).to redirect_to(registration_ticket_path(existing_registration.slug))
        expect(flash[:notice]).to eq("Registration was successfully updated.")
      end

      it "cannot update event_id" do
        original_event_id = existing_registration.event_id

        patch event_registration_path(existing_registration),
              params: { event_registration: { event_id: new_event.id } }

        expect(existing_registration.reload.event_id).to eq(original_event_id)
      end
    end

    describe "DELETE /event_registrations/:id" do
      context "when the record exists" do
        it "deletes the registration" do
          expect {
            delete event_registration_path(existing_registration)
          }.to change(EventRegistration, :count).by(-1)

          expect(response).to redirect_to(event_registrations_path)
          expect(flash[:notice]).to eq("Registration deleted.")
        end
      end

      context "when destroy fails" do
        it "sets alert flash" do
          allow_any_instance_of(EventRegistration).to receive(:destroy).and_return(false)
          allow_any_instance_of(EventRegistration).to receive_message_chain(:errors, :full_messages)
                                                        .and_return([ "Could not delete" ])

          delete event_registration_path(existing_registration)

          expect(response).to redirect_to(event_registrations_path)
          expect(flash[:alert]).to eq("Could not delete")
        end
      end
    end
  end

  # ============================================================
  # GUEST
  # ============================================================
  context "as a guest" do
    describe "GET /event_registrations" do
      it "redirects to new user session path" do
        get event_registrations_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "POST /event_registrations" do
      it "does not create a registration" do
        expect {
          post event_registrations_path,
               params: { event_registration: { event_id: event.id, registrant_id: regular_user.person.id } }
        }.not_to change(EventRegistration, :count)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "PATCH /event_registrations/:id" do
      it "redirects to new user session path" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { event_id: new_event.id } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "DELETE /event_registrations/:id" do
      it "does not delete the registration" do
        expect {
          delete event_registration_path(existing_registration)
        }.not_to change(EventRegistration, :count)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
