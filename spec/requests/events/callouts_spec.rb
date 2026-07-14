require "rails_helper"

RSpec.describe "Events::Callouts", type: :request do
  let(:registration) { create(:event_registration, event: event) }

  # These pages are reachable by slug (no login), so the built-in callout
  # visibility rules are the only gate. Hidden callouts redirect back to the
  # ticket so a stray link can't surface training content on a non-training event.
  describe "GET /registration/:slug/faq" do
    context "on a facilitator training" do
      let(:event) { create(:event, facilitator_training: true) }

      it "renders the FAQ" do
        get registration_faq_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "on a non-training event" do
      let(:event) { create(:event, facilitator_training: false) }

      it "redirects to the ticket" do
        get registration_faq_path(registration.slug)
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end
  end

  describe "GET /registration/:slug/handouts" do
    context "on a facilitator training" do
      let(:event) { create(:event, facilitator_training: true) }

      it "renders the handouts page" do
        get registration_handouts_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "on a non-training event" do
      let(:event) { create(:event, facilitator_training: false) }

      it "redirects to the ticket" do
        get registration_handouts_path(registration.slug)
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end
  end

  describe "GET /registration/:slug/videoconference" do
    let(:event) { create(:event, videoconference_url: "https://example.com/zoom") }

    it "renders resources linked to the built-in callout below the content" do
      resource = create(:resource)
      create(:downloadable_asset, owner: resource)
      create(:registration_ticket_callout, event:, magic_key: "videoconference",
        title: "Videoconference", resources: [ resource ])

      get registration_videoconference_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(rails_blob_path(resource.downloadable_asset.file, only_path: true))
    end
  end

  describe "GET /registration/:slug/ce" do
    context "when CE is registered" do
      let(:event) { create(:event) }

      before do
        license = create(:professional_license, person: registration.registrant, number: nil)
        create(:continuing_education_registration, event_registration: registration, professional_license: license)
      end

      it "renders the CE page" do
        get registration_ce_path(registration.slug)
        expect(response).to have_http_status(:success)
      end

      context "with checkout=success" do
        it "shows a success flash" do
          get registration_ce_path(registration.slug, checkout: "success")
          expect(flash[:notice]).to eq("Your CE payment was successful.")
        end
      end

      context "with checkout=cancelled" do
        it "shows a cancelled flash" do
          get registration_ce_path(registration.slug, checkout: "cancelled")
          expect(flash[:alert]).to eq("CE payment was cancelled. You can try again whenever you're ready.")
        end
      end
    end

    context "when CE is not registered" do
      let(:event) { create(:event) }

      it "renders the opt-in form" do
        get registration_ce_path(registration.slug)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Request CE credit")
      end
    end
  end

  # Every built-in page renders the intro text an admin types into its materialized
  # callout row's "Callout page text" (description), above the app-controlled body —
  # the same field custom callouts use. Previously CE/handouts/FAQ/scholarship
  # silently dropped it.
  describe "built-in page intro text (callout row description)" do
    let(:event) { create(:event, facilitator_training: true) }

    before { DefaultTicketCallouts.seed(event) }

    def describe_callout(magic_key, html)
      event.registration_ticket_callouts.find_by(magic_key:).update!(description: html)
    end

    it "renders the CE callout's description" do
      describe_callout("ce_hours", "<p>Bring your license number.</p>")
      get registration_ce_path(registration.slug)
      expect(response.body).to include("Bring your license number.")
    end

    it "renders the handouts callout's description" do
      describe_callout("handouts", "<p>Download these before class.</p>")
      get registration_handouts_path(registration.slug)
      expect(response.body).to include("Download these before class.")
    end

    it "renders the FAQ callout's description" do
      describe_callout("faq", "<p>Read this intro first.</p>")
      get registration_faq_path(registration.slug)
      expect(response.body).to include("Read this intro first.")
    end

    it "renders the scholarship callout's description" do
      registration.update!(scholarship_requested: true)
      describe_callout("scholarship", "<p>About your scholarship.</p>")
      get registration_scholarship_path(registration.slug)
      expect(response.body).to include("About your scholarship.")
    end
  end

  describe "POST /registration/:slug/ce/pay" do
    let(:event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 15_000) }
    let(:fake_session) { double(url: "https://checkout.stripe.com/test", id: "cs_test_123") }

    before do
      license = create(:professional_license, person: registration.registrant, number: "LIC-1")
      create(:continuing_education_registration, event_registration: registration,
             professional_license: license, cost_cents: 15_000)

      fake_processor = double(checkout: fake_session)
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
    end

    it "redirects to Stripe Checkout when a CE balance is due" do
      post registration_ce_pay_path(registration.slug)
      expect(response).to redirect_to("https://checkout.stripe.com/test")
      expect(response.status).to eq(303)
    end

    it "includes ce_registration_id and event_registration_id in the checkout metadata" do
      captured = nil
      fake_processor = double
      allow(fake_processor).to receive(:checkout) { |params| captured = params; fake_session }
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)

      post registration_ce_pay_path(registration.slug)

      expect(captured[:metadata]).to include(
        ce_registration_id: registration.continuing_education_registrations.first.id,
        event_registration_id: registration.id
      )
    end

    it "updates the checkout_session_id on the registration" do
      post registration_ce_pay_path(registration.slug)
      expect(registration.reload.checkout_session_id).to eq("cs_test_123")
    end

    context "when no CE registration exists" do
      before { registration.continuing_education_registrations.destroy_all }

      it "redirects with an alert" do
        post registration_ce_pay_path(registration.slug)
        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:alert]).to eq("No CE payment is due.")
      end
    end

    context "when the CE balance is zero" do
      before do
        registration.continuing_education_registrations.first.update!(cost_cents: 0)
      end

      it "redirects with an alert" do
        post registration_ce_pay_path(registration.slug)
        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:alert]).to eq("No CE payment is due.")
      end
    end
  end
end
