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

    it "links resources on the built-in callout to their own page, not inline" do
      resource = create(:resource)
      create(:downloadable_asset, owner: resource)
      create(:registration_ticket_callout, event:, magic_key: "videoconference",
        title: "Videoconference", resources: [ resource ])

      get registration_videoconference_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(registration_resource_path(registration.slug, resource, return_to: "videoconference"))
      # The file itself is only shown on the resource's own page, not embedded here.
      expect(response.body).not_to include(rails_blob_path(resource.downloadable_asset.file, only_path: true))
    end
  end

  # The single-resource page is where a document is actually shown: the inline
  # preview and download button live here, not on the callout list pages that
  # link to it.
  describe "GET /registration/:slug/resource/:resource_id" do
    let(:event) { create(:event) }

    context "with a PDF resource" do
      let(:resource) { create(:resource) }

      before { create(:downloadable_asset, owner: resource) }

      it "shows the PDF inline preview and a download button" do
        get registration_resource_path(registration.slug, resource)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("type=\"application/pdf\"")
        expect(response.body).to include(rails_blob_path(resource.downloadable_asset.file, disposition: :inline))
        expect(response.body).to include("fa-download")
      end
    end

    context "with a non-PDF resource" do
      let(:resource) { create(:resource) }

      before { create(:downloadable_asset, :with_image, owner: resource) }

      it "renders the preview instead of an inline PDF viewer" do
        get registration_resource_path(registration.slug, resource)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("type=\"application/pdf\"")
      end
    end

    context "eyebrow" do
      let(:resource) { create(:resource) }

      it "returns to the built-in callout it came from" do
        get registration_resource_path(registration.slug, resource, return_to: "videoconference")

        expect(response.body).to include(registration_videoconference_path(registration.slug))
      end

      it "returns to the custom callout it came from" do
        callout = create(:registration_ticket_callout, event:, title: "Parking")

        get registration_resource_path(registration.slug, resource, return_to: "callout", callout_id: callout.id)

        expect(response.body).to include(event_registration_ticket_callout_path(event, callout, reg: registration.slug))
        expect(response.body).to include("Back to Parking")
      end

      it "falls back to the ticket when reached directly" do
        get registration_resource_path(registration.slug, resource)

        expect(response.body).to include(registration_ticket_path(registration.slug))
        expect(response.body).to include("Back to ticket")
      end
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
