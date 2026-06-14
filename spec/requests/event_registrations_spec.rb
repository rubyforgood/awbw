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

      it "filters registrations by organization_id" do
        organization = create(:organization)
        matching_reg = create(:event_registration)
        create(:event_registration_organization, event_registration: matching_reg, organization: organization)

        get event_registrations_path(organization_id: organization.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(matching_reg.registrant.first_name)
        expect(response.body).not_to include(existing_registration.registrant.first_name)
      end

      it "exports CSV with headers and data only (no captions)" do
        get event_registrations_path, params: { format: :csv }

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".csv")

        rows = CSV.parse(response.body)
        expect(rows.size).to be >= 1
        expect(rows.first).to eq([ "First name", "Last name", "Email", "Phone", "Event", "Status", "Scholarship", "Scholarship completed", "Payment status", "Payment total" ])

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
          "Not paid in full",
          ""
        ]
        expect(data_rows).to include(expected_row)
      end

      context "registration form icon" do
        let(:reg_form) { create(:form, :standalone, name: "Registration Form") }
        let(:person) { existing_registration.registrant }

        it "shows green icon when person submitted the current registration form" do
          create(:event_form, event: event, form: reg_form, role: "registration")
          create(:form_submission, person: person, form: reg_form)

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

    describe "POST /event_registrations" do
      it "creates registration and redirects admin to confirm page" do
        expect {
          post event_registrations_path,
               params: { return_to: "registrants", event_registration: { event_id: event.id, registrant_id: admin.person.id } }
        }.to change(EventRegistration, :count).by(1)

        registration = EventRegistration.last
        expect(response).to redirect_to(confirm_event_registration_path(registration, return_to: "registrants"))
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

    describe "PATCH /event_registrations/:id" do
      it "can update registration" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { event_id: new_event.id } }

        # No explicit return_to: admins land back on the management roster, not
        # the public registration show.
        expect(response).to redirect_to(registrants_event_path(new_event))
        expect(existing_registration.reload.event_id).to eq(new_event.id)
      end

      it "updates the CE credit requested flag" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { ce_credit_requested: "1" } }

        expect(existing_registration.reload.ce_credit_requested).to be(true)
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
        link_scholarship(existing_registration, amount_cents: 5000)

        expect { unrequest(existing_registration) }
          .not_to change { existing_registration.scholarships.count }
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
    end

    describe "DELETE /event_registrations/:id" do
      it "can delete registration" do
        expect {
          delete event_registration_path(existing_registration)
        }.to change(EventRegistration, :count).by(-1)
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

        it "shows 'No other affiliations on record' when the person has none" do
          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("No other affiliations on record")
        end

        it "shows the affiliation pill inline on the linked org" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Counselor")
          expect(response.body).not_to include("Counselor — inactive")
        end

        it "renders an inline editable title field for a non-facilitator affiliation" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include('name="affiliation[title]"')
        end

        it "does not render an editable field for a Facilitator affiliation" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Facilitator")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).not_to include('name="affiliation[title]"')
        end

        it "links 'View profile' to the org profile affiliations anchor in a new tab" do
          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("View profile")
          expect(response.body).to include("#{organization_path(organization)}#affiliations")
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
          expect(response.body).not_to include("Facilitator — inactive")
        end

        it "shows a facilitator affiliation as inactive once it has ended" do
          create(:affiliation, person: regular_user.person, organization: organization,
                               title: "Facilitator", end_date: 1.month.ago.to_date)

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Facilitator")
          expect(response.body).to include("inactive")
        end

        it "shows 'Title matches form' when the affiliation title equals the submitted position for the submitted org" do
          create(:affiliation, person: regular_user.person, organization: organization, title: "Counselor")
          submit_form(org_name: organization.name, position: "Counselor")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("Title matches form")
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
          submit_form(org_name: "Typed Agency")

          get link_organization_event_registration_path(existing_registration)

          expect(response.body).to include("registration form submission")
          expect(response.body).to include(event_public_registration_path(event, reg: existing_registration.slug))
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
