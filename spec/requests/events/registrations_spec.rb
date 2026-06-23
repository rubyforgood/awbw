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
      # A facilitator training shows the full built-in set, including the
      # training-only Handouts and FAQ cards.
      let(:event) { create(:event, facilitator_training: true) }

      it "renders the consolidated magic callout cards" do
        get registration_ticket_path(registration.slug)
        expect(response.body).to include("view your balance")
        expect(response.body).to include("W-9, invoice, and receipt")
        expect(response.body).to include("Worksheets and resources for the training")
        expect(response.body).to include("Frequently asked questions")
      end

      it "omits the training-only Handouts and FAQ cards on a non-training event" do
        non_training = create(:event, facilitator_training: false)
        reg = create(:event_registration, event: non_training, registrant: user.person)
        get registration_ticket_path(reg.slug)
        expect(response.body).not_to include("Worksheets and resources for the training")
        expect(response.body).not_to include("Frequently asked questions")
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

    it "defaults the eyebrow to the ticket" do
      get registration_invoice_path(registration.slug)
      expect(response.body).to include(registration_ticket_path(registration.slug))
      expect(response.body).to include("Back to ticket")
    end

    it "returns to the forms callout when reached from forms" do
      get registration_invoice_path(registration.slug, return_to: "forms")
      expect(response.body).to include(registration_forms_path(registration.slug))
      expect(response.body).to include("Back to forms")
    end

    it "returns to the payment callout when reached from payment" do
      get registration_invoice_path(registration.slug, return_to: "payment")
      expect(response.body).to include(registration_payment_path(registration.slug))
      expect(response.body).to include("Back to payment")
    end

    context "as a guest" do
      before { sign_out user }

      it "renders the invoice (slug is authorization)" do
        get registration_invoice_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "for a free event" do
      let(:event) { create(:event, cost_cents: 0) }

      it "redirects to the ticket (nothing to invoice)" do
        get registration_invoice_path(registration.slug)
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end

    context "with an invalid slug" do
      it "returns 404" do
        get registration_invoice_path("nonexistent-slug")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /registration/:slug/receipt" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    context "when paid in full" do
      before { create(:allocation, allocatable: registration, amount: 150_000) }

      it "renders the receipt with a zero balance" do
        get registration_receipt_path(registration.slug)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("RECEIPT")
        expect(response.body).to include("Paid in full")
        expect(response.body).to include("AWBW 2-Day Art Facilitator Training")
        expect(response.body).to include("Balance due")
      end

      context "as a guest" do
        before { sign_out user }

        it "renders the receipt (slug is authorization)" do
          get registration_receipt_path(registration.slug)
          expect(response).to have_http_status(:success)
        end
      end
    end

    it "redirects to the ticket when a balance is still due" do
      get registration_receipt_path(registration.slug)
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end

    context "for a free event" do
      let(:event) { create(:event, cost_cents: 0) }

      it "redirects to the ticket (nothing to receipt)" do
        get registration_receipt_path(registration.slug)
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end

    context "with an invalid slug" do
      it "returns 404" do
        get registration_receipt_path("nonexistent-slug")
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

    it "links to the registrant's form responses when a submission is on file" do
      registration.update!(scholarship_requested: true)
      form = create(:form)
      create(:event_form, event: event, form: form, role: "registration")
      create(:form_submission, :with_event, event: event, person: registration.registrant, form: form)

      get registration_scholarship_path(registration.slug)

      expect(response.body).to include("Review your form responses")
      expect(response.body).to include(event_public_registration_path(event, reg: registration.slug))
    end

    it "omits the form-responses link when the registrant has no submission" do
      registration.update!(scholarship_requested: true)

      get registration_scholarship_path(registration.slug)

      expect(response.body).not_to include("Review your form responses")
    end
  end

  describe "GET /registration/:slug/faq" do
    let(:event) { create(:event, facilitator_training: true) }
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
      expect(response.body).to include("View invoice")
      expect(response.body).to include("Prefer to pay by check?")
      expect(response.body).to include("A Window Between Worlds")
    end

    it "hides the pay button and check instructions once paid in full" do
      create(:allocation, allocatable: registration, amount: event.cost_cents)
      get registration_payment_path(registration.slug)
      expect(response.body).not_to include("Pay with Credit Card")
      expect(response.body).not_to include("Prefer to pay by check?")
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

    it "always links to the invoice, returning to forms" do
      get registration_forms_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(registration_invoice_path(registration.slug, return_to: "forms"))
    end

    it "links the W-9 to its resource page when present, returning to forms" do
      w9 = create(:resource, title: "W-9", kind: "Form")
      get registration_forms_path(registration.slug)
      expect(response.body).to include(registration_resource_path(registration.slug, w9, return_to: "forms"))
      expect(response.body).not_to include("/documents/awbw-w9.pdf")
    end

    it "omits the receipt link until the balance is paid in full" do
      get registration_forms_path(registration.slug)
      expect(response.body).not_to include(registration_receipt_path(registration.slug))
    end

    it "links to the receipt once paid in full, returning to forms" do
      paid_event = create(:event, cost_cents: 150_000)
      paid_registration = create(:event_registration, event: paid_event, registrant: user.person)
      create(:allocation, allocatable: paid_registration, amount: 150_000)

      get registration_forms_path(paid_registration.slug)
      expect(response.body).to include(registration_receipt_path(paid_registration.slug, return_to: "forms"))
    end
  end

  describe "GET /registration/:slug/handouts" do
    let(:event) { create(:event, facilitator_training: true) }
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "links each handout to its registrant resource page, returning to handouts" do
      handout = create(:resource, title: "Aha Moments", kind: "Handout")
      get registration_handouts_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(registration_resource_path(registration.slug, handout, return_to: "handouts"))
    end

    it "shows a placeholder when no handouts are present" do
      get registration_handouts_path(registration.slug)
      expect(response.body).to include("Training handouts will be available here soon.")
    end
  end

  describe "GET /registration/:slug/resource/:resource_id" do
    let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

    it "renders the resource with a back-to-ticket link and a download button" do
      resource = create(:resource, title: "Aha Moments", kind: "Handout")
      create(:downloadable_asset, owner: resource)

      get registration_resource_path(registration.slug, resource)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Aha Moments")
      expect(response.body).to include(registration_ticket_path(registration.slug))
      expect(response.body).to include(rails_blob_path(resource.downloadable_asset.file, only_path: true))
    end

    it "is reachable by slug without logging in" do
      resource = create(:resource, title: "Aha Moments", kind: "Handout")

      get registration_resource_path(registration.slug, resource)

      expect(response).to have_http_status(:success)
    end

    it "returns to the handouts callout with a 'Handouts detail' header when reached from handouts" do
      resource = create(:resource, title: "Aha Moments", kind: "Handout")

      get registration_resource_path(registration.slug, resource, return_to: "handouts")

      expect(response.body).to include(registration_handouts_path(registration.slug))
      expect(response.body).to include("Back to handouts")
      expect(response.body).not_to include("Back to ticket")
      expect(response.body).to include("Handouts detail")
      expect(response.body).to include("Aha Moments")
    end

    it "returns to the forms callout with a 'Forms detail' header when reached from forms" do
      resource = create(:resource, title: "Letter to Supervisors", kind: "Form")

      get registration_resource_path(registration.slug, resource, return_to: "forms")

      expect(response.body).to include(registration_forms_path(registration.slug))
      expect(response.body).to include("Back to forms")
      expect(response.body).to include("Forms detail")
      expect(response.body).to include("Letter to Supervisors")
    end
  end

  describe "GET /registration/:slug/videoconference" do
    let(:event) do
      create(:event, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours,
                     videoconference_url: "https://awbw.zoom.us/j/88285411273",
                     videoconference_label: "Zoom", videoconference_passcode: "secret123")
    end
    # Within a week and intends to pay → the connection details are visible.
    let!(:registration) { create(:event_registration, event: event, registrant: user.person, intends_to_pay: true) }

    it "shows the join link and add-to-calendar options" do
      get registration_videoconference_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("https://awbw.zoom.us/j/88285411273")
      expect(response.body).to include("Add to your calendar")
    end

    it "shows the meeting ID parsed from the URL and the passcode" do
      get registration_videoconference_path(registration.slug)
      expect(response.body).to include("Meeting ID")
      expect(response.body).to include("882 8541 1273")
      expect(response.body).to include("Passcode")
      expect(response.body).to include("secret123")
    end

    it "withholds the link and credentials more than a week before the event" do
      event.update!(start_date: 8.days.from_now, end_date: 8.days.from_now + 2.hours)
      get registration_videoconference_path(registration.slug)
      expect(response.body).not_to include("88285411273")
      expect(response.body).not_to include("secret123")
      expect(response.body).to include("about a week before the event")
    end

    it "withholds the link and credentials until the registrant has payment access" do
      registration.update!(intends_to_pay: false)
      get registration_videoconference_path(registration.slug)
      expect(response.body).not_to include("88285411273")
      expect(response.body).not_to include("secret123")
      expect(response.body).to include("payment is on file")
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

    it "zeroes any scholarship award when cancelling" do
      costed_registration = create(:event_registration, event: create(:event, cost_cents: 50_000),
                                                         registrant: user.person, status: "registered")
      scholarship = create(:scholarship, recipient: user.person, amount_cents: 50_000)
      allocation = create(:allocation, source: scholarship, allocatable: costed_registration, amount: 50_000)

      post registration_cancel_path(costed_registration.slug)

      expect(costed_registration.reload.status).to eq("cancelled")
      expect(scholarship.reload.amount_cents).to eq(0)
      expect(allocation.reload.amount).to eq(0)
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
      form.form_submissions.create!(person: user.person, event: event)
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
end
