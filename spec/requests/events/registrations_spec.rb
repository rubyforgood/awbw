require "rails_helper"

RSpec.describe "Events::Registrations", type: :request do
  let(:user) { create(:user, :with_person) }
  let(:event) { create(:event) }

  before { sign_in user }

  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  describe "GET /registration/:slug" do
    let(:admin) { create(:user, :with_person, super_user: true) }
    let(:other_user) { create(:user, :with_person) }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    context "as the registrant (owner)" do
      it "shows the registration ticket" do
        get registration_ticket_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows the registration ticket" do
        get registration_ticket_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "as another user" do
      before { sign_in other_user }

      it "shows the registration ticket (slug is authorization)" do
        get registration_ticket_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "as a guest" do
      before { sign_out user }

      it "shows the registration ticket (slug is authorization)" do
        get registration_ticket_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "with an invalid slug" do
      it "returns 404" do
        get registration_ticket_path("nonexistent-slug")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /registration/:slug/resend_confirmation" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "sends confirmation email and redirects back" do
      expect {
        post registration_resend_confirmation_path(registration.slug)
      }.to have_enqueued_mail(EventMailer, :event_registration_confirmation)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:notice]).to eq("Confirmation email sent.")
    end

    context "as a guest" do
      before { sign_out user }

      it "sends confirmation email (slug is authorization)" do
        expect {
          post registration_resend_confirmation_path(registration.slug)
        }.to have_enqueued_mail(EventMailer, :event_registration_confirmation)

        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end
  end

  describe "POST /registration/:slug/cancel" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person, status: "registered") }

    it "cancels an active registration" do
      post registration_cancel_path(registration.slug)

      expect(registration.reload.status).to eq("cancelled")
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:notice]).to eq("Your registration has been cancelled.")
    end

    it "does not cancel an already cancelled registration" do
      registration.update!(status: "cancelled")

      post registration_cancel_path(registration.slug)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:alert]).to eq("Registration is already cancelled.")
    end

    context "as a guest" do
      before { sign_out user }

      it "cancels the registration (slug is authorization)" do
        post registration_cancel_path(registration.slug)

        expect(registration.reload.status).to eq("cancelled")
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end
  end

  describe "POST /registration/:slug/reactivate" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person, status: "cancelled") }

    it "reactivates a cancelled registration" do
      post registration_reactivate_path(registration.slug)

      expect(registration.reload.status).to eq("registered")
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:notice]).to eq("Your registration has been reactivated.")
    end

    it "does not reactivate an already active registration" do
      registration.update!(status: "registered")

      post registration_reactivate_path(registration.slug)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:alert]).to eq("Registration is not cancelled.")
    end

    context "as a guest" do
      before { sign_out user }

      it "reactivates the registration (slug is authorization)" do
        post registration_reactivate_path(registration.slug)

        expect(registration.reload.status).to eq("registered")
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end
  end

  describe "GET /events/:event_id/public_registration (show)" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    before do
      EventRegistrationFormBuilder.build!(event)
      form = event.forms.find_by(name: "Public Registration")
      form.person_forms.create!(person: user.person)
    end

    it "allows access with a valid slug" do
      get event_public_registration_path(event, reg: registration.slug)
      expect(response).to have_http_status(:success)
    end

    it "returns 404 with an invalid slug" do
      get event_public_registration_path(event, reg: "bogus-slug")
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 with a slug from a different event" do
      other_event = create(:event)
      other_registration = create(:event_registration, event: other_event, registrant: user.person)

      get event_public_registration_path(event, reg: other_registration.slug)
      expect(response).to have_http_status(:not_found)
    end

    context "as a guest" do
      before { sign_out user }

      it "allows access with a valid slug" do
        get event_public_registration_path(event, reg: registration.slug)
        expect(response).to have_http_status(:success)
      end
    end
  end

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
          .and_return([ "Cannot register" ])
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
      let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

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
      let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

      before do
        allow_any_instance_of(EventRegistration)
          .to receive(:destroy)
          .and_return(false)
        allow_any_instance_of(EventRegistration)
          .to receive_message_chain(:errors, :full_messages)
          .and_return([ "Cannot delete" ])
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
