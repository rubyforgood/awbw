require "rails_helper"

RSpec.describe RegistrationTicketCalloutDecorator, type: :decorator do
  describe "#resource_cards" do
    let(:callout) { create(:registration_ticket_callout) }
    let(:resource) { create(:resource, title: "Worksheet") }

    before do
      create(:registration_ticket_callout_resource, registration_ticket_callout: callout,
             resource:, subtitle: "Short line")
    end

    it "builds a card per linked resource, reading the materialized subtitle" do
      cards = callout.decorate.resource_cards(registrant_slug: "abc", return_to: "handouts")

      expect(cards.map(&:title)).to eq([ "Worksheet" ])
      expect(cards.first.subtitle).to eq("Short line")
    end

    it "carries the callout id in the href only for the generic callout origin" do
      generic = callout.decorate.resource_cards(registrant_slug: "abc", return_to: "callout").first
      handouts = callout.decorate.resource_cards(registrant_slug: "abc", return_to: "handouts").first

      expect(generic.href).to include("callout_id=#{callout.id}")
      expect(handouts.href).not_to include("callout_id")
    end
  end
end
