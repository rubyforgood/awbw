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

    context "magic callouts" do
      it "renders the consolidated magic callout cards" do
        get registration_ticket_path(registration.slug)
        expect(response.body).to include("view your balance")
        expect(response.body).to include("W-9, invoice, and letter to supervisors")
        expect(response.body).to include("Worksheets and resources for the training")
        expect(response.body).to include("Frequently asked questions")
      end
    end

    context "with an invalid slug" do
      it "returns 404" do
        get registration_ticket_path("nonexistent-slug")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /registration/:slug/invoice" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "renders the invoice for the registrant" do
      get registration_invoice_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("INVOICE")
      expect(response.body).to include("AWBW 2-Day Art Facilitator Training")
      expect(response.body).to include("$1,500")
    end

    context "as a guest" do
      before { sign_out user }

      it "renders the invoice (slug is authorization)" do
        get registration_invoice_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "with an invalid slug" do
      it "returns 404" do
        get registration_invoice_path("nonexistent-slug")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /registration/:slug/scholarship" do
    let(:event) { create(:event, cost_cents: 150_000) }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "redirects to the ticket when nothing was requested or awarded" do
      get registration_scholarship_path(registration.slug)
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end

    it "shows a pending state when a scholarship was requested but not awarded" do
      registration.update!(scholarship_requested: true)
      get registration_scholarship_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Scholarship requested")
    end

    it "shows the award amount, funder, criteria, and tasks when awarded via a grant" do
      grant = create(:grant)
      scholarship = create(:scholarship, grant: grant, amount_cents: 75_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 75_000)

      get registration_scholarship_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("$750")
      expect(response.body).to include(grant.funder_name)
      expect(response.body).to include("Eligibility criteria")
      expect(response.body).to include("Tasks to complete")
    end
  end

  describe "GET /registration/:slug/faq" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "renders the training FAQ with the folded-in contact link" do
      get registration_faq_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Frequently asked questions")
      expect(response.body).to include("Is the training trauma-informed?")
      expect(response.body).to include("Still have questions?")
      expect(response.body).to include(contact_us_path)
    end
  end

  describe "GET /registration/:slug/payment" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "shows the allocation ledger, balance due, and check instructions" do
      create(:allocation, allocatable: registration, amount: 500)
      get registration_payment_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Payment history")
      expect(response.body).to include("Amount due")
      expect(response.body).to include("Pay with Credit Card")
      expect(response.body).to include("Paying by check?")
      expect(response.body).to include("A Window Between Worlds")
    end

    it "hides the pay button and check instructions once paid in full" do
      create(:allocation, allocatable: registration, amount: event.cost_cents)
      get registration_payment_path(registration.slug)
      expect(response.body).not_to include("Pay with Credit Card")
      expect(response.body).not_to include("Paying by check?")
    end
  end

  describe "GET /registration/:slug/certificate" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "redirects to the ticket when the certificate is not yet available" do
      get registration_certificate_path(registration.slug)
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end

    it "renders the certificate once the training is complete and attended" do
      event.update!(start_date: 3.days.ago, end_date: 2.days.ago)
      registration.update!(status: "attended")
      get registration_certificate_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Certificate of completion")
      expect(response.body).to include(registration.registrant.full_name)
    end
  end

  describe "GET /registration/:slug/ce" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "shows status, cost, and the license number on file" do
      registration.update!(ce_credit_requested: true, ce_hours_requested: 6, ce_license_number: "LIC123")
      get registration_ce_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Requested")
      expect(response.body).to include("Hours requested")
      expect(response.body).to include("$150")
      expect(response.body).to include("LIC123")
    end

    it "notes when the license number is not yet on file" do
      registration.update!(ce_credit_requested: true, ce_hours_requested: 6, ce_license_number: nil)
      get registration_ce_path(registration.slug)
      expect(response.body).to include("We don't have your license number on file yet.")
    end
  end

  describe "GET /registration/:slug/forms" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "always links to the W-9 and invoice" do
      get registration_forms_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("/documents/awbw-w9.pdf")
      expect(response.body).to include(registration_invoice_path(registration.slug))
    end

    it "links to the letter-to-supervisors PDF below them when present" do
      letter = create(:resource, title: "Letter to Supervisors", kind: "Form")
      get registration_forms_path(registration.slug)
      expect(response.body.index("/documents/awbw-w9.pdf")).to be < response.body.index(resource_download_path(letter))
    end
  end

  describe "GET /registration/:slug/handouts" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "links to seeded handout resources" do
      handout = create(:resource, title: "AHA Moments", kind: "Handout")
      get registration_handouts_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(resource_path(handout))
    end

    it "shows a placeholder when no handouts are present" do
      get registration_handouts_path(registration.slug)
      expect(response.body).to include("Training handouts will be available here soon.")
    end
  end

  describe "GET /registration/:slug/portal" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "renders portal info with a link to the home screen" do
      get registration_portal_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Facilitator Portal access")
      expect(response.body).to include(root_path)
    end
  end

  describe "GET /registration/:slug/videoconference" do
    let(:event) { create(:event, videoconference_url: "https://awbw.zoom.us/j/123", videoconference_label: "Zoom") }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "shows the join link and add-to-calendar options" do
      get registration_videoconference_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("https://awbw.zoom.us/j/123")
      expect(response.body).to include("Add to your calendar")
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
    let(:fake_session) { double(url: "https://checkout.stripe.com/test", id: "cs_test_123") }

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

  describe "GET /events/:event_id/public_registration (show)" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    before do
      form = FormBuilderService.new(
        name: "Extended Event Registration",
        sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
      ).call
      EventForm.create!(event: event, form: form, role: "registration")
      form = event.registration_form
      form.form_submissions.create!(person: user.person)
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
    let(:event) { create(:event, cost_cents: 0) }

    context "with credit card payment" do
      let(:event) { create(:event, cost_cents: 15_00) }
      let(:fake_session) { double(url: "https://checkout.stripe.com/test", id: "cs_test_123") }

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
