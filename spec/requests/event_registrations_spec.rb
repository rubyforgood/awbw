require "rails_helper"

RSpec.describe "EventRegistrations", type: :request do
  before(:all) do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

  let(:user) { create(:user, first_name: "John", last_name: "Doe", email: "john.doe@example.com") }
  let(:event) { create(:event, title: "Test Event") }

  before do
    sign_in user
  end

  describe "POST /event_registrations" do
    context "with valid parameters" do
      it "creates a new EventRegistration" do
        expect {
          post event_registrations_path, params: {event_id: event.id},
            headers: {"Accept" => "text/vnd.turbo-stream.html"}
        }.to change(EventRegistration, :count).by(1)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "creates registration with correct attributes" do
        post event_registrations_path, params: {event_id: event.id}

        registration = EventRegistration.last
        expect(registration.event_id).to eq(event.id)
        expect(registration.registrant).to eq(user)
      end
    end

    context "with invalid parameters" do
      it "does not create a new EventRegistration" do
        expect {
          post event_registrations_path, params: {event_id: nil}
        }.to change(EventRegistration, :count).by(0)
      end
    end

    context "when user is not authenticated" do
      before { sign_out user }

      it "redirects to sign in page" do
        post event_registrations_path, params: {event_id: event.id}
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    xdescribe "POST /event_registrations/bulk_create" do
      let(:event1) { create(:event, title: "Event 1") }
      let(:event2) { create(:event, title: "Event 2") }
      let(:event3) { create(:event, title: "Event 3") }

      context "with valid event IDs" do
        it "creates multiple EventRegistrations" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id]}
          }.to change(EventRegistration, :count).by(2)
        end

        it "redirects to events page with success notice" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id]}
          expect(response).to redirect_to(events_path)
          expect(flash[:notice]).to eq("Successfully registered for 2 events.")
        end

        it "creates registrations with user information" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id]}

          registration = EventRegistration.last
          expect(registration.event_id).to eq(event1.id)
          expect(registration.first_name).to eq("John")
          expect(registration.last_name).to eq("Doe")
          expect(registration.email).to eq("john.doe@example.com")
        end

        it "handles single event registration" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id]}
          expect(response).to redirect_to(events_path)
          expect(flash[:notice]).to eq("Successfully registered for 1 event.")
        end

        it "removes duplicate event IDs" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event1.id, event2.id]}
          }.to change(EventRegistration, :count).by(2)
        end
      end

      context "with no event IDs" do
        it "redirects with alert when event_ids is nil" do
          post bulk_create_event_registrations_path, params: {}
          expect(response).to redirect_to(events_path)
          expect(flash[:alert]).to eq("Please select at least one event.")
        end
      end

      context "when user is already registered for some events" do
        before do
          create(:event_registration, event: event1, email: user.email)
        end

        it "does not create any registrations due to rollback" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id]}
          }.to change(EventRegistration, :count).by(0)
        end

        it "redirects with alert about already registered events" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id]}
          expect(response).to redirect_to(events_path)
          expect(flash[:alert]).to include("Event 'Event 1': You are already registered for this event.")
        end
      end

      xcontext "when user has no first_name or last_name" do # TODO - figure out why this use case is here
        let(:user_without_names) { create(:user, first_name: nil, last_name: nil, email: "test@example.com") }

        before { sign_in user_without_names }

        it "uses email prefix as first name and 'User' as last name" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id]}

          registration = EventRegistration.last
          expect(registration.first_name).to eq("test")
          expect(registration.last_name).to eq("User")
          expect(registration.email).to eq("test@example.com")
        end
      end

      xcontext "when user has only first_name" do # TODO - figure out why this use case is here
        let(:user_with_first_name) { create(:user, first_name: "Alice", last_name: nil, email: "alice@example.com") }

        before { sign_in user_with_first_name }

        it "uses provided first name and 'User' as last name" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id]}

          registration = EventRegistration.last
          expect(registration.first_name).to eq("Alice")
          expect(registration.last_name).to eq("User")
          expect(registration.email).to eq("alice@example.com")
        end
      end

      context "when registration validation fails" do
        before do
          allow_any_instance_of(EventRegistration).to receive(:save).and_return(false)
          allow_any_instance_of(EventRegistration).to receive(:errors).and_return(
            double(full_messages: ["Email is invalid"])
          )
        end

        it "redirects with error message" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id]}
          expect(response).to redirect_to(events_path)
          expect(flash[:alert]).to include("Email is invalid")
        end

        it "does not create any registrations when validation fails" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id]}
          }.to change(EventRegistration, :count).by(0)
        end
      end

      context "when user is not authenticated" do
        before { sign_out user }

        it "redirects to sign in page" do
          post bulk_create_event_registrations_path, params: {event_ids: [event1.id]}
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "with mixed valid and invalid scenarios" do
        before do
          create(:event_registration, event: event1, email: user.email)
          allow_any_instance_of(EventRegistration).to receive(:save).and_return(false)
          allow_any_instance_of(EventRegistration).to receive(:errors).and_return(
            double(full_messages: ["Some validation error"])
          )
        end

        it "handles mixed scenarios correctly" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id, event3.id]}
          }.to change(EventRegistration, :count).by(0)

          expect(response).to redirect_to(events_path)
          expect(flash[:alert]).to include("Event 'Event 1': You are already registered for this event.")
          expect(flash[:alert]).to include("Some validation error")
        end
      end

      context "with string event IDs" do
        it "converts string IDs to integers" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id.to_s, event2.id.to_s]}
          }.to change(EventRegistration, :count).by(2)
        end
      end

      context "with non-existent event IDs" do
        it "handles non-existent event IDs gracefully" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [99999, event1.id]}
          }.to change(EventRegistration, :count).by(0)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    xdescribe "transaction handling" do
      let(:event1) { create(:event, title: "Event 1") }
      let(:event2) { create(:event, title: "Event 2") }

      context "when bulk_create encounters errors" do
        before do
          create(:event_registration, event: event1, email: user.email)
          allow_any_instance_of(EventRegistration).to receive(:save).and_return(false)
          allow_any_instance_of(EventRegistration).to receive(:errors).and_return(
            double(full_messages: ["Validation failed"])
          )
        end

        it "rolls back all changes when any registration fails" do
          expect {
            post bulk_create_event_registrations_path, params: {event_ids: [event1.id, event2.id]}
          }.to change(EventRegistration, :count).by(0)
        end
      end
    end
  end
end
