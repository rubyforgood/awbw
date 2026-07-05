require "rails_helper"

RSpec.describe "Registration ticket callouts", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, :publicly_visible) }

  describe "GET /events/:event_id/registration_ticket_callouts/:id" do
    it "renders the callout's title and description" do
      callout = create(:registration_ticket_callout, event:, title: "Parking",
        description: "<p>Use the north lot.</p>")

      get event_registration_ticket_callout_path(event, callout)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Parking")
      expect(response.body).to include("Use the north lot.")
    end

    it "redirects to the event when the callout has no description or resource" do
      callout = create(:registration_ticket_callout, event:, description: "")

      get event_registration_ticket_callout_path(event, callout)

      expect(response).to redirect_to(event_path(event))
    end

    it "is publicly readable even when the event is not public" do
      private_event = create(:event, :unpublished, :ended)
      callout = create(:registration_ticket_callout, event: private_event,
        title: "Parking", description: "<p>Use the north lot.</p>")

      get event_registration_ticket_callout_path(private_event, callout)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Parking")
    end

    it "renders a resource-linked callout even when it has no description" do
      resource = create(:resource)
      create(:downloadable_asset, owner: resource)
      callout = create(:registration_ticket_callout, event:, description: "", resource:)

      get event_registration_ticket_callout_path(event, callout)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(rails_blob_path(resource.downloadable_asset.file, only_path: true))
    end

    it "does not find a callout belonging to a different event" do
      other_callout = create(:registration_ticket_callout, description: "<p>Hi.</p>")

      get event_registration_ticket_callout_path(event, other_callout)

      expect(response).to have_http_status(:not_found)
    end

    context "when linked to a resource with a downloadable file" do
      let(:resource) { create(:resource) }
      let(:callout) do
        create(:registration_ticket_callout, event:, title: "Workbook",
          description: "<p>Read this first.</p>", resource:)
      end

      before { create(:downloadable_asset, owner: resource) }

      it "renders the callout content above the resource display and a download button" do
        get event_registration_ticket_callout_path(event, callout)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Read this first.")
        expect(response.body).to include(rails_blob_path(resource.downloadable_asset.file, only_path: true))
      end
    end

    context "when linked to a resource without a downloadable file" do
      let(:resource) { create(:resource) }
      let(:callout) do
        create(:registration_ticket_callout, event:,
          description: "<p>Read this first.</p>", resource:)
      end

      it "does not render a download button" do
        get event_registration_ticket_callout_path(event, callout)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("fa-download")
      end
    end
  end

  describe "creating callouts through the event form" do
    before { sign_in admin }

    it "creates callouts from nested attributes and assigns positions in form order" do
      patch event_path(event), params: {
        event: {
          title: event.title,
          start_date: event.start_date,
          end_date: event.end_date,
          registration_ticket_callouts_attributes: {
            "0" => { title: "First", callout_type: "reference", color_class: "green" },
            "1" => { title: "Second", callout_type: "action" },
            "2" => { title: "Third", callout_type: "reference" }
          }
        }
      }

      ordered = event.registration_ticket_callouts.reload.ordered
      expect(ordered.map(&:title)).to eq(%w[First Second Third])
      expect(ordered.map(&:position)).to eq([ 1, 2, 3 ])
    end

    it "links a callout to a resource through nested attributes" do
      resource = create(:resource)

      patch event_path(event), params: {
        event: {
          title: event.title,
          start_date: event.start_date,
          end_date: event.end_date,
          registration_ticket_callouts_attributes: {
            "0" => { title: "Workbook", callout_type: "reference", resource_id: resource.id }
          }
        }
      }

      callout = event.registration_ticket_callouts.reload.find_by(title: "Workbook")
      expect(callout.resource).to eq(resource)
    end
  end

  describe "PATCH /events/:event_id/registration_ticket_callouts/:id (reorder)" do
    it "moves the callout and reflows the others for an admin" do
      sign_in admin
      first = create(:registration_ticket_callout, event:)
      second = create(:registration_ticket_callout, event:)

      patch event_registration_ticket_callout_path(event, second), params: { position: 1 }

      expect(response).to have_http_status(:ok)
      expect(event.registration_ticket_callouts.ordered).to eq([ second, first ])
    end

    it "is not permitted for a non-manager" do
      sign_in create(:user)
      create(:registration_ticket_callout, event:)
      callout = create(:registration_ticket_callout, event:) # position 2

      patch event_registration_ticket_callout_path(event, callout), params: { position: 1 }

      expect(response).to redirect_to(root_path)
      expect(callout.reload.position).to eq(2)
    end
  end
end
