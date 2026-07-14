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

    it "redirects a hidden callout's page back to the event" do
      callout = create(:registration_ticket_callout, :hidden, event:, description: "<p>Draft.</p>")

      get event_registration_ticket_callout_path(event, callout)

      expect(response).to redirect_to(event_path(event))
    end

    it "redirects a not-yet-dripped callout's page back to the event" do
      callout = create(:registration_ticket_callout, event:, description: "<p>Later.</p>",
        display_from: 1.day.from_now)

      get event_registration_ticket_callout_path(event, callout)

      expect(response).to redirect_to(event_path(event))
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

    context "when linked to a PDF resource" do
      let(:resource) { create(:resource) }
      let(:callout) { create(:registration_ticket_callout, event:, resource:, description: "") }

      before { create(:downloadable_asset, owner: resource) }

      it "shows the PDF in the browser's inline viewer" do
        get event_registration_ticket_callout_path(event, callout)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("type=\"application/pdf\"")
        expect(response.body).to include(rails_blob_path(resource.downloadable_asset.file, disposition: :inline))
      end
    end

    context "when linked to a non-PDF resource" do
      let(:resource) { create(:resource) }
      let(:callout) { create(:registration_ticket_callout, event:, resource:, description: "") }

      before { create(:downloadable_asset, :with_image, owner: resource) }

      it "renders the preview instead of an inline PDF viewer" do
        get event_registration_ticket_callout_path(event, callout)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("type=\"application/pdf\"")
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

      ordered = event.registration_ticket_callouts.custom.reload.ordered
      expect(ordered.map(&:title)).to eq(%w[First Second Third])
      expect(ordered.map(&:position)).to eq([ 1, 2, 3 ])
    end

    it "links a callout to resources through nested attributes" do
      resource = create(:resource)

      patch event_path(event), params: {
        event: {
          title: event.title,
          start_date: event.start_date,
          end_date: event.end_date,
          registration_ticket_callouts_attributes: {
            "0" => { title: "Workbook", callout_type: "reference",
                     registration_ticket_callout_resources_attributes: { "0" => { resource_id: resource.id } } }
          }
        }
      }

      callout = event.registration_ticket_callouts.reload.find_by(title: "Workbook")
      expect(callout.resources).to eq([ resource ])
    end

    it "saves a callout's drip display date through nested attributes" do
      patch event_path(event), params: {
        event: {
          title: event.title,
          start_date: event.start_date,
          end_date: event.end_date,
          registration_ticket_callouts_attributes: {
            "0" => { title: "Handbook", callout_type: "reference", display_from: "2026-08-01" }
          }
        }
      }

      callout = event.registration_ticket_callouts.reload.find_by(title: "Handbook")
      expect(callout.display_from.to_date).to eq(Date.new(2026, 8, 1))
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

  describe "restoring a built-in through the event form" do
    before { sign_in admin }

    it "resets a callout flagged reset_to_default on the main save" do
      training = create(:event, :publicly_visible, facilitator_training: true)
      callout = create(:registration_ticket_callout, event: training, magic_key: "faq", title: "Edited", hidden: true)

      patch event_path(training), params: {
        event: {
          title: training.title, start_date: training.start_date, end_date: training.end_date,
          registration_ticket_callouts_attributes: {
            "0" => { id: callout.id, title: "Still edited", reset_to_default: "1" }
          }
        }
      }

      expect(callout.reload.title).to eq("Frequently asked questions")
      expect(callout.hidden).to be(false)
    end
  end

  describe "seeding built-in callouts on save" do
    before { sign_in admin }

    it "materializes the built-in callouts when an event is updated" do
      patch event_path(event), params: {
        event: { title: event.title, start_date: event.start_date, end_date: event.end_date }
      }

      expect(event.registration_ticket_callouts.magic.pluck(:magic_key)).to contain_exactly(
        "payment", "certificate", "scholarship", "ce_hours", "event_details",
        "videoconference", "handouts", "faq"
      )
    end
  end

  describe "the event editor" do
    before { sign_in admin }

    it "renders a materialized content callout as an editable field with a restore checkbox" do
      create(:registration_ticket_callout, event:, magic_key: "faq",
        title: "Frequently asked questions")

      get edit_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("name=\"event[registration_ticket_callouts_attributes][0][title]\"")
      expect(response.body).to include("name=\"event[registration_ticket_callouts_attributes][0][reset_to_default]\"")
    end

    it "renders a behavioral magic callout with the same editable fields as a custom one" do
      create(:registration_ticket_callout, event:, magic_key: "certificate",
        title: "Certificate of completion")

      get edit_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("name=\"event[registration_ticket_callouts_attributes][0][title]\"")
      expect(response.body).to include("name=\"event[registration_ticket_callouts_attributes][0][description]\"")
      expect(response.body).to include("name=\"event[registration_ticket_callouts_attributes][0][published]\"")
      expect(response.body).to include("Add resource") # every built-in can link resources now
      expect(response.body).to include("name=\"event[registration_ticket_callouts_attributes][0][reset_to_default]\"")
    end

    it "shows the restore checkbox only once the built-in has been customized" do
      # Seed unedited built-ins, then load the editor.
      DefaultTicketCallouts.seed(event)
      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")

      get edit_event_path(event)
      expect(response.body).to include("Matches default")
      expect(response.body).not_to include("reset_to_default")

      faq.update!(title: "Our FAQ")
      get edit_event_path(event)
      expect(response.body).to include("reset_to_default")
    end

    it "gives the Payment card an add-another linked-resource picker" do
      resource = create(:resource, title: "W-9")
      create(:registration_ticket_callout, event:, magic_key: "payment", title: "Payment", resources: [ resource ])

      get edit_event_path(event)

      expect(response).to have_http_status(:ok)
      # One dropdown per linked resource, plus an "Add resource" link (cocoon).
      expect(response.body).to match(/registration_ticket_callout_resources_attributes\]\[\d+\]\[resource_id\]/)
      expect(response.body).to include("Add resource")
    end
  end
end
