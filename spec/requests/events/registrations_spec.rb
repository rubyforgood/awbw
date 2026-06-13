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

    it "creates notification records and redirects back" do
      expect {
        post registration_resend_confirmation_path(registration.slug)
      }.to change(Notification, :count).by(2)

      expect(Notification.last(2).map(&:kind)).to match_array(
        %w[event_registration_confirmation event_registration_confirmation_fyi]
      )
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:notice]).to eq("Confirmation email sent.")
    end

    context "as a guest" do
      before { sign_out user }

      it "creates notification records (slug is authorization)" do
        expect {
          post registration_resend_confirmation_path(registration.slug)
        }.to change(Notification, :count).by(2)

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

  describe "POST /registration/:slug/pay" do
    let(:event) { create(:event, cost_cents: 15_00) }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }
    let(:fake_session) { double(url: "https://checkout.stripe.com/test") }

    before do
      fake_processor = double(checkout: fake_session)
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
    end

    it "redirects to Stripe Checkout when payment is due" do
      post registration_pay_path(registration.slug)

      expect(response).to redirect_to("https://checkout.stripe.com/test")
      expect(response.status).to eq(303)
    end

    it "shows an alert when no payment is due" do
      event.update!(cost_cents: 0)

      post registration_pay_path(registration.slug)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
      expect(flash[:alert]).to eq("No payment is due.")
    end
  end

  describe "GET /submission/:slug" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    before do
      form = FormBuilderService.new(
        name: "Extended Event Registration",
        sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
      ).call
      EventForm.create!(event: event, form: form, role: "registration")
      event.registration_form.form_submissions.create!(person: user.person)
    end

    it "allows access with a valid slug" do
      get submission_path(registration.slug)
      expect(response).to have_http_status(:success)
    end

    it "returns 404 with an invalid slug" do
      get submission_path("bogus-slug")
      expect(response).to have_http_status(:not_found)
    end

    context "as a guest" do
      before { sign_out user }

      it "allows access with a valid slug (the slug is the access token)" do
        get submission_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /events/:event_id/registrations" do
    let(:event) { create(:event, cost_cents: 0) }

    context "with credit card payment" do
      let(:event) { create(:event, cost_cents: 15_00) }
      let(:fake_session) { double(url: "https://checkout.stripe.com/test") }

      before do
        fake_processor = double(checkout: fake_session)
        allow_any_instance_of(Person).to receive(:set_payment_processor)
        allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
      end

      it "redirects to Stripe Checkout" do
        post event_registrant_registration_path(event_id: event.id)

        expect(response).to redirect_to("https://checkout.stripe.com/test")
        expect(response.status).to eq(303)
      end
    end

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

      it "creates notification records" do
        expect {
          post event_registrant_registration_path(event_id: event.id),
            headers: turbo_headers
        }.to change(Notification, :count).by(2)

        expect(Notification.last(2).map(&:kind)).to match_array(
          %w[event_registration_confirmation event_registration_confirmation_fyi]
        )
      end
    end

    context "when a cancelled registration exists" do
      let!(:cancelled_registration) do
        create(:event_registration, event: event, registrant: user.person, status: "cancelled")
      end

      it "reactivates the existing registration instead of creating a new one" do
        expect {
          post event_registrant_registration_path(event_id: event.id),
            headers: turbo_headers
        }.not_to change(EventRegistration, :count)

        expect(cancelled_registration.reload.status).to eq("registered")
        expect(response).to have_http_status(:ok)
        expect(flash.now[:notice]).to eq("Your registration has been reactivated.")
      end

      it "creates notification records on reactivation" do
        expect {
          post event_registrant_registration_path(event_id: event.id),
            headers: turbo_headers
        }.to change(Notification, :count).by(2)

        expect(Notification.last(2).map(&:kind)).to match_array(
          %w[event_registration_confirmation event_registration_confirmation_fyi]
        )
      end

      it "reactivates via HTML format and redirects to ticket" do
        post event_registrant_registration_path(event_id: event.id)

        expect(cancelled_registration.reload.status).to eq("registered")
        expect(response).to redirect_to(registration_ticket_path(cancelled_registration.slug))
        expect(flash[:notice]).to eq("Your registration has been reactivated.")
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
