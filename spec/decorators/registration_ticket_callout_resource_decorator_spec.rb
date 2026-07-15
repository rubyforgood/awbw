require "rails_helper"

RSpec.describe RegistrationTicketCalloutResourceDecorator, type: :decorator do
  include Rails.application.routes.url_helpers

  describe "#card_subtitle" do
    it "returns the materialized subtitle when present" do
      link = build(:registration_ticket_callout_resource, subtitle: "Reflect on the workshop")
      expect(link.decorate.card_subtitle).to eq("Reflect on the workshop")
    end

    it "falls back to a neutral label when the subtitle is blank" do
      link = build(:registration_ticket_callout_resource, subtitle: "")
      expect(link.decorate.card_subtitle).to eq("Open this document")
    end
  end

  describe "#to_card" do
    let(:resource) { create(:resource, title: "Worksheet") }
    let(:link) { create(:registration_ticket_callout_resource, resource:, subtitle: "Short line") }

    it "titles the card by the resource and reads the join-row subtitle" do
      card = link.decorate.to_card(registrant_slug: "abc", return_to: "handouts")

      expect(card.title).to eq("Worksheet")
      expect(card.subtitle).to eq("Short line")
    end

    it "links a registrant to the resource page returning to this origin" do
      card = link.decorate.to_card(registrant_slug: "abc", return_to: "handouts")

      expect(card.href).to eq(registration_resource_path("abc", resource, return_to: "handouts"))
    end

    it "falls back to the resource's own page without a registrant slug" do
      card = link.decorate.to_card(registrant_slug: nil, return_to: "callout")

      expect(card.href).to eq(resource_path(resource))
    end
  end
end
