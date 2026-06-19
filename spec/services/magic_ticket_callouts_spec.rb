require "rails_helper"

RSpec.describe MagicTicketCallouts do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }

  def card_titles(reg)
    described_class.new(reg).cards.map(&:title)
  end

  describe "#cards" do
    it "includes the invoice card only when an invoice was requested" do
      registration.update!(invoice_requested: false)
      expect(card_titles(registration)).not_to include("View invoice")

      registration.update!(invoice_requested: true)
      expect(card_titles(registration)).to include("View invoice")
    end

    it "includes the W-9 card only when a W-9 was requested" do
      registration.update!(w9_requested: false)
      expect(card_titles(registration)).not_to include("Download W-9")

      registration.update!(w9_requested: true)
      expect(card_titles(registration)).to include("Download W-9")
    end

    it "includes the event-details and CE-hours cards only when the event has them" do
      event.update!(event_details: "Bring supplies", ce_hours_details: "6 hours")
      titles = card_titles(registration)
      expect(titles).to include(event.event_details_label, event.ce_hours_details_label)
    end

    it "includes the scholarship card when requested but not yet awarded" do
      registration.update!(scholarship_requested: true)
      card = described_class.new(registration).cards.find { |c| c.title == "Scholarship" }
      expect(card).to be_present
      expect(card.subtitle).to eq("Your scholarship request status")
    end

    it "includes the scholarship card when awarded, even without the requested flag" do
      registration.update!(scholarship_requested: false)
      scholarship = create(:scholarship, amount_cents: 1000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      card = described_class.new(registration).cards.find { |c| c.title == "Scholarship" }
      expect(card).to be_present
      expect(card.subtitle).to eq("Your award — amount, funder, and tasks")
    end

    it "omits the scholarship card when neither requested nor awarded" do
      registration.update!(scholarship_requested: false)
      expect(card_titles(registration)).not_to include("Scholarship")
    end

    it "always ends with the reference FAQ and 'Questions & next steps' cards" do
      event.update!(event_details: nil, ce_hours_details: nil)
      registration.update!(w9_requested: false, invoice_requested: false, scholarship_requested: false)
      cards = described_class.new(registration).cards
      expect(cards.map(&:title)).to eq([ "Frequently asked questions", "Questions & next steps" ])
      expect(cards.map(&:trailing_icon).uniq).to eq([ "fa-solid fa-circle-info" ])
    end

    it "orders cards: event details, CE hours, scholarship, W-9, invoice, FAQ, questions" do
      event.update!(event_details: "Bring supplies", ce_hours_details: "6 hours")
      registration.update!(w9_requested: true, invoice_requested: true, scholarship_requested: true)
      expect(card_titles(registration)).to eq([
        event.event_details_label,
        event.ce_hours_details_label,
        "Scholarship",
        "Download W-9",
        "View invoice",
        "Frequently asked questions",
        "Questions & next steps"
      ])
    end
  end

  describe "a card" do
    it "exposes the link, target, and presentation the partial needs" do
      registration.update!(invoice_requested: true)
      card = described_class.new(registration).cards.find { |c| c.title == "View invoice" }

      expect(card.href).to eq(Rails.application.routes.url_helpers.registration_invoice_path(registration.slug))
      expect(card.target).to eq("_blank")
      expect(card.display_icon_class).to eq("fa-solid fa-file-invoice-dollar")
      expect(card.theme).to eq(DomainTheme.swatch("indigo"))
    end
  end
end
