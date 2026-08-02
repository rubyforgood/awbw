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

  describe "#config_suppression_hint" do
    def builtin_callout(builtin_key, event:, hidden: true)
      create(:registration_ticket_callout, event:, builtin_key:, hidden:,
             title: builtin_key.humanize)
    end

    it "names the config change even when the callout is unpublished" do
      callout = builtin_callout("payment", event: create(:event, cost_cents: 0), hidden: true)
      expect(callout.decorate.config_suppression_hint).to eq("set an event cost above $0")
    end

    it "names setting CE hours for a CE callout on an event that offers none" do
      callout = builtin_callout("ce_hours", event: create(:event, ce_hours_offered: nil))
      expect(callout.decorate.config_suppression_hint).to eq("set CE hours above 0 under form settings")
    end

    it "is nil once the event is configured for the callout" do
      callout = builtin_callout("payment", event: create(:event, cost_cents: 5_000))
      expect(callout.decorate.config_suppression_hint).to be_nil
    end

    it "is nil for a custom (non-built-in) callout" do
      callout = create(:registration_ticket_callout, builtin_key: nil)
      expect(callout.decorate.config_suppression_hint).to be_nil
    end
  end
end
