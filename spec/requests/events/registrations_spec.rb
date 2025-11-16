require "rails_helper"

RSpec.describe "Events::Registrations", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }

  before { sign_in user }

  let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

  describe "POST /events/:event_id/registrations" do
    context "when successful" do
      it "creates a registration and returns turbo stream" do
        expect {
          post event_registrant_registration_path(event_id: event.id),
            headers: turbo_headers
        }.to change(EventRegistration, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(flash.now[:notice]).to eq("You have successfully registered for this event.")
      end
    end

    context "when creation fails" do
      before do
        allow_any_instance_of(EventRegistration)
          .to receive(:save)
          .and_return(false)
        allow_any_instance_of(EventRegistration)
          .to receive_message_chain(:errors, :full_messages)
          .and_return(["Cannot register"])
      end

      it "returns turbo stream with alert" do
        post event_registrant_registration_path(event_id: event.id),
          headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(flash.now[:alert]).to eq("Cannot register")
      end
    end
  end

  describe "DELETE /events/:event_id/registrations" do
    context "when registration exists" do
      let!(:registration) { create(:event_registration, event: event, registrant: user) }

      it "destroys registration and returns turbo stream" do
        expect {
          delete event_registrant_registration_path(event_id: event.id),
            headers: turbo_headers
        }.to change(EventRegistration, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(flash.now[:notice]).to eq("You are no longer registered.")
      end
    end

    context "when registration does not exist" do
      it "returns turbo stream with alert" do
        delete event_registrant_registration_path(event_id: event.id),
          headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(flash.now[:alert]).to eq("Registration not found")
      end
    end

    context "when destroy fails" do
      let!(:registration) { create(:event_registration, event: event, registrant: user) }

      before do
        allow_any_instance_of(EventRegistration)
          .to receive(:destroy)
          .and_return(false)
        allow_any_instance_of(EventRegistration)
          .to receive_message_chain(:errors, :full_messages)
          .and_return(["Cannot delete"])
      end

      it "returns turbo stream with alert" do
        delete event_registrant_registration_path(event_id: event.id),
          headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(flash.now[:alert]).to eq("Cannot delete")
      end
    end
  end
end
