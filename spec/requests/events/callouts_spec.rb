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

  describe "GET /registration/:slug/forms" do
    context "on a paid non-training event" do
      let(:event) { create(:event, facilitator_training: false, cost_cents: 1099) }

      it "renders the forms page" do
        get registration_forms_path(registration.slug)
        expect(response).to have_http_status(:success)
      end
    end

    context "on a free non-training event" do
      let(:event) { create(:event, facilitator_training: false, cost_cents: 0) }

      it "redirects to the ticket" do
        get registration_forms_path(registration.slug)
        expect(response).to redirect_to(registration_ticket_path(registration.slug))
      end
    end

    context "when the Forms callout is materialized" do
      let(:event) { create(:event, cost_cents: 1099) }
      let!(:w9) { create(:resource, title: "W-9") }

      it "links the Forms callout's resources, and drops the W-9 when removed" do
        DefaultTicketCallouts.seed(event)

        get registration_forms_path(registration.slug)
        expect(response.body).to include(registration_resource_path(registration.slug, w9, return_to: "forms"))

        event.registration_ticket_callouts.find_by(magic_key: "forms").resources.destroy_all
        get registration_forms_path(registration.slug)
        expect(response.body).not_to include(registration_resource_path(registration.slug, w9, return_to: "forms"))
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
end
