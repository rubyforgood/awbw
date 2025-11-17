require "rails_helper"

RSpec.describe "EventRegistrations", type: :request do
  let(:user) { create(:user, first_name: "John", last_name: "Doe", email: "john.doe@example.com") }
  let(:event) { create(:event, title: "Test Event") }

  before do
    sign_in user
  end
  describe "GET /event_registrations" do
    it "paginates results" do
      registrations = create_list(:event_registration, 3)

      get event_registrations_path, params: {number_of_items_per_page: 1}

      expect(response).to have_http_status(:success)

      first = ActionView::RecordIdentifier.dom_id(registrations.first)
      second = ActionView::RecordIdentifier.dom_id(registrations.second)

      expect(response.body).to include(first)
      expect(response.body).not_to include(second)
    end
  end

  describe "POST /event_registrations" do
    context "with valid parameters" do
      it "creates a new EventRegistration" do
        expect {
          post event_registrations_path, params: {event_registration: {event_id: event.id, registrant_id: user.id}}
        }.to change(EventRegistration, :count).by(1)

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
  end

  describe "PATCH /event_registrations/:id" do
    let!(:registration) { create(:event_registration, event: event, registrant: user) }

    context "with valid parameters" do
      let(:new_event) { create(:event) }

      it "updates the event registration" do
        patch event_registration_path(registration), params: {
          event_registration: {event_id: new_event.id}
        }

        expect(response).to redirect_to(event_registrations_path)
        expect(flash[:notice]).to eq("Registration was successfully updated.")
        expect(registration.reload.event_id).to eq(new_event.id)
      end
    end

    context "with invalid parameters" do
      it "renders edit with unprocessable status" do
        patch event_registration_path(registration), params: {
          event_registration: {event_id: nil}
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when user is not authenticated" do
      before { sign_out user }

      it "redirects to sign in page" do
        patch event_registration_path(registration), params: {
          event_registration: {event_id: event.id}
        }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /event_registrations/:id" do
    let!(:registration) { create(:event_registration, event: event, registrant: user) }

    context "when the record exists" do
      it "deletes the event registration" do
        expect {
          delete event_registration_path(registration)
        }.to change(EventRegistration, :count).by(-1)

        expect(response).to redirect_to(event_registrations_path)
        expect(flash[:notice]).to eq("Registration deleted.")
      end
    end

    context "when the record fails to delete" do
      it "sets an alert flash" do
        allow_any_instance_of(EventRegistration).to receive(:destroy).and_return(false)
        allow_any_instance_of(EventRegistration).to receive_message_chain(:errors, :full_messages)
          .and_return(["Could not delete"])

        delete event_registration_path(registration)

        expect(response).to redirect_to(event_registrations_path)
        expect(flash[:alert]).to eq("Could not delete")
      end
    end

    context "when user is not authenticated" do
      before { sign_out user }

      it "redirects to sign in page" do
        delete event_registration_path(registration)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
