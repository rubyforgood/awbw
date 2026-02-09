require "rails_helper"
require "csv"

RSpec.describe "EventRegistrations", type: :request do
  let(:regular_user) { create(:user, first_name: "John", last_name: "Doe", email: "john.doe@example.com") }
  let(:admin)        { create(:user, super_user: true) }
  let(:other_user)   { create(:user) }

  let(:event)        { create(:event, title: "Test Event") }
  let(:new_event)    { create(:event) }

  let!(:existing_registration) { create(:event_registration, event: event, registrant: regular_user) }

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

      it "exports CSV with headers and data only (no captions)" do
        get event_registrations_path, params: { format: :csv }

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".csv")

        rows = CSV.parse(response.body)
        expect(rows.size).to be >= 1
        expect(rows.first).to eq([ "First name", "Last name", "Email", "Event" ])

        data_rows = rows.drop(1)
        expect(data_rows).not_to be_empty
        expected_row = [
          regular_user.first_name.to_s,
          regular_user.last_name.to_s,
          regular_user.email.to_s,
          event.title.to_s
        ]
        expect(data_rows).to include(expected_row)
      end

      xit "paginates results" do
        registrations = create_list(:event_registration, 3)

        get event_registrations_path, params: { number_of_items_per_page: 1 }

        expect(response).to have_http_status(:success)

        first  = ActionView::RecordIdentifier.dom_id(registrations.first)
        second = ActionView::RecordIdentifier.dom_id(registrations.second)

        expect(response.body).to include(first)
        expect(response.body).not_to include(second)
      end
    end

    describe "POST /event_registrations" do
      it "can create registration" do
        expect {
          post event_registrations_path,
               params: { event_registration: { event_id: event.id, registrant_id: admin.id } }
        }.to change(EventRegistration, :count).by(1)
      end
    end

    describe "PATCH /event_registrations/:id" do
      it "can update registration" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { event_id: new_event.id } }

        expect(response).to redirect_to(event_registrations_path)
        expect(existing_registration.reload.event_id).to eq(new_event.id)
      end
    end

    describe "DELETE /event_registrations/:id" do
      it "can delete registration" do
        expect {
          delete event_registration_path(existing_registration)
        }.to change(EventRegistration, :count).by(-1)
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

    describe "POST /event_registrations" do
      context "when no registration exists yet" do
        xit "creates a new EventRegistration" do # figure out why this is broken now
          expect {
            post event_registrations_path,
                 params: {
                   event_registration: {
                     event_id: new_event.id,
                     registrant_id: regular_user.id
                   }
                 }
          }.to change(EventRegistration, :count).by(1)
        end
      end

      context "when a registration already exists" do
        xit "does not create a duplicate registration" do # figure out why this is broken now
          expect {
            post event_registrations_path,
                 params: {
                   event_registration: {
                     event_id: event.id,
                     registrant_id: regular_user.id
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

    describe "PATCH /event_registrations/:id" do
      context "with valid parameters" do
        xit "updates the registration" do # TODO - figure out why this is broken now
          patch event_registration_path(existing_registration),
                params: { event_registration: { event_id: new_event.id } }

          expect(response).to redirect_to(event_path(existing_registration.event))
          expect(flash[:notice]).to eq("Registration was successfully updated.")
          expect(existing_registration.reload.event_id).to eq(new_event.id)
        end
      end

      context "with invalid parameters" do
        it "redirects to root" do
          patch event_registration_path(existing_registration),
                params: { event_registration: { event_id: nil } }
          expect(response).to redirect_to(root_path)
        end
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
      it "redirects to root" do
        get event_registrations_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /event_registrations" do
      it "does not create a registration" do
        expect {
          post event_registrations_path,
               params: { event_registration: { event_id: event.id, registrant_id: regular_user.id } }
        }.not_to change(EventRegistration, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /event_registrations/:id" do
      it "redirects to root" do
        patch event_registration_path(existing_registration),
              params: { event_registration: { event_id: new_event.id } }

        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /event_registrations/:id" do
      it "does not delete the registration" do
        expect {
          delete event_registration_path(existing_registration)
        }.not_to change(EventRegistration, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
