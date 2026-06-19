require "rails_helper"

RSpec.describe MagicTicketCallouts do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }

  def card_titles(reg)
    described_class.new(reg).cards.map(&:title)
  end

  def card(reg, title)
    described_class.new(reg).cards.find { |c| c.title == title }
  end

  describe "#cards" do
    it "shows the always-present cards for a bare paid-cost registration" do
      expect(card_titles(registration)).to eq([
        "Payment", "Forms", "Handouts", "Frequently asked questions", "Facilitator Portal access"
      ])
    end

    it "omits the payment card for a free event" do
      event.update!(cost_cents: 0)
      expect(card_titles(registration)).not_to include("Payment")
    end

    it "makes the payment card an action card while a balance is due, reference once paid" do
      due = card(registration, "Payment")
      expect(due.theme).to eq(DomainTheme.swatch("orange"))
      expect(due.trailing_icon).to eq("fa-solid fa-arrow-right")

      create(:allocation, source: create(:payment), allocatable: registration, amount: event.cost_cents)
      paid = card(registration, "Payment")
      expect(paid.theme).to eq(DomainTheme.swatch("blue"))
      expect(paid.trailing_icon).to eq("fa-solid fa-arrow-right")
    end

    it "uses the arrow trailing icon for every card" do
      event.update!(ce_hours_details: "6 hours", videoconference_url: "https://example.zoom.us/j/1")
      trailing = described_class.new(registration).cards.map(&:trailing_icon).uniq
      expect(trailing).to eq([ "fa-solid fa-arrow-right" ])
    end

    it "greys the portal card until the registrant completes the training with an account" do
      expect(card(registration, "Facilitator Portal access").theme).to eq(DomainTheme.swatch("gray"))

      registration.update!(status: "attended")
      expect(card(registration, "Facilitator Portal access").theme).to eq(DomainTheme.swatch("green"))
    end

    it "shows the certificate card only once it is available" do
      expect(card_titles(registration)).not_to include("Certificate of completion")

      event.update!(start_date: 3.days.ago, end_date: 2.days.ago)
      registration.update!(status: "attended")
      expect(card_titles(registration)).to include("Certificate of completion")
    end

    it "shows the videoconference card only when the event has a link" do
      expect(card_titles(registration)).not_to include("Videoconference")
      event.update!(videoconference_url: "https://example.zoom.us/j/123")
      expect(card_titles(registration)).to include("Videoconference")
    end

    it "shows the CE card when the event offers CE or the registrant requested it" do
      expect(card_titles(registration)).not_to include(event.ce_hours_details_label)
      registration.update!(ce_credit_requested: true)
      expect(card_titles(registration)).to include(event.ce_hours_details_label)
    end

    it "themes the CE card as action until requested with hours and a license, then reference" do
      registration.update!(ce_credit_requested: true, ce_hours_requested: nil, ce_license_number: nil)
      expect(card(registration, event.ce_hours_details_label).theme).to eq(DomainTheme.swatch("orange"))

      registration.update!(ce_hours_requested: 6, ce_license_number: "LIC123")
      complete = card(registration, event.ce_hours_details_label)
      expect(complete.theme).to eq(DomainTheme.swatch("indigo"))
      expect(complete.subtitle).to eq("6 hours · $150 due")
    end

    it "shows the scholarship card when requested or awarded" do
      expect(card_titles(registration)).not_to include("Scholarship")
      registration.update!(scholarship_requested: true)
      expect(card(registration, "Scholarship").subtitle).to eq("Your scholarship request status")
    end

    it "places payment first and FAQ last in the full ordering" do
      event.update!(event_details: "Bring supplies", ce_hours_details: "6 hours",
                    videoconference_url: "https://example.zoom.us/j/123",
                    start_date: 3.days.ago, end_date: 2.days.ago)
      registration.update!(status: "attended", scholarship_requested: true)
      expect(card_titles(registration)).to eq([
        "Payment",
        "Certificate of completion",
        "Scholarship",
        event.ce_hours_details_label,
        event.event_details_label,
        "Videoconference",
        "Forms",
        "Handouts",
        "Frequently asked questions",
        "Facilitator Portal access"
      ])
    end
  end
end
