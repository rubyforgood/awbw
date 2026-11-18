require "rails_helper"

RSpec.describe RegistrantCalloutLink do
  include Rails.application.routes.url_helpers

  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }
  let(:resource) { create(:resource, title: "Training notes") }

  describe "#path" do
    it "opens a content callout's event-scoped page with the registrant's slug" do
      callout = create(:registration_ticket_callout, event:)

      expect(described_class.new(registration, callout).path)
        .to eq(event_registration_ticket_callout_path(event, callout, reg: registration.slug))
    end

    it "opens a form-delivering callout's person-first forms page" do
      callout = create(:registration_ticket_callout, event:, form: create(:form))

      expect(described_class.new(registration, callout).path)
        .to eq(registration_callout_form_path(registration.slug, callout))
    end

    it "opens one resource on the callout, returning to that callout's page" do
      callout = create(:registration_ticket_callout, event:, resource:)

      expect(described_class.new(registration, callout, resource:).path)
        .to eq(registration_resource_path(registration.slug, resource, return_to: "callout", callout_id: callout.id))
    end

    it "is nil for a resource the callout doesn't link" do
      callout = create(:registration_ticket_callout, event:)

      expect(described_class.new(registration, callout, resource:).path).to be_nil
    end

    it "is nil when the ticket hides the callout from this registrant" do
      callout = create(:registration_ticket_callout, :attended_gated, event:)

      expect(described_class.new(registration, callout).path).to be_nil
      registration.update!(status: "attended")
      expect(described_class.new(registration, callout).path).to be_present
    end

    it "is nil for an unpublished callout" do
      callout = create(:registration_ticket_callout, :hidden, event:)

      expect(described_class.new(registration, callout).path).to be_nil
    end

    it "is nil for a callout with no page to open" do
      callout = create(:registration_ticket_callout, event:, description: nil)

      expect(described_class.new(registration, callout).path).to be_nil
    end

    it "is nil for another event's callout" do
      callout = create(:registration_ticket_callout)

      expect(described_class.new(registration, callout).path).to be_nil
    end
  end

  describe "#label" do
    it "names the resource when one is picked, else the callout" do
      callout = create(:registration_ticket_callout, event:, title: "After the training", resource:)

      expect(described_class.new(registration, callout).label).to eq("After the training")
      expect(described_class.new(registration, callout, resource:).label).to eq("Training notes")
    end
  end
end
