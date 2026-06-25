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
        "Make your payment", "Forms", "Handouts", "Frequently asked questions"
      ])
    end

    it "omits the payment card for a free event" do
      event.update!(cost_cents: 0)
      expect(card_titles(registration)).not_to include("Payment")
    end

    it "makes the payment card an action card while a balance is due, reference once paid" do
      due = card(registration, "Make your payment")
      expect(due.theme).to eq(DomainTheme.swatch("orange"))
      expect(due.badge).to end_with("due")
      expect(due.badge_classes).to be_nil
      expect(due.trailing_icon).to eq("fa-solid fa-arrow-right")

      create(:allocation, source: create(:payment), allocatable: registration, amount: event.cost_cents)
      paid = card(registration, "Payment")
      expect(paid.theme).to eq(DomainTheme.swatch("blue"))
      expect(paid.badge).to eq("Paid")
      expect(paid.badge_classes).to include("blue")
      expect(paid.trailing_icon).to eq("fa-solid fa-arrow-right")
    end

    it "uses the arrow trailing icon for every card" do
      event.update!(ce_hours_details: "6 hours", videoconference_url: "https://example.zoom.us/j/1")
      trailing = described_class.new(registration).cards.map(&:trailing_icon).uniq
      expect(trailing).to eq([ "fa-solid fa-arrow-right" ])
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

    it "shows the CE card only when the registrant requested CE credit" do
      event.update!(ce_hours_details: "6 hours")
      expect(card_titles(registration)).not_to include(event.ce_hours_details_label)
      registration.update!(ce_credit_requested: true)
      expect(card_titles(registration)).to include(event.ce_hours_details_label)
    end

    it "shows an amber 'what's needed' CE badge until complete, then a teal amount due" do
      registration.update!(ce_credit_requested: true, ce_hours_requested: nil, ce_license_number: nil)
      both = card(registration, event.ce_hours_details_label)
      expect(both.theme).to eq(DomainTheme.swatch("teal"))
      expect(both.subtitle).to eq("Continuing education credit")
      expect(both.badge).to eq("Hours & license number needed")
      expect(both.badge_classes).to be_nil

      registration.update!(ce_hours_requested: 6, ce_license_number: nil)
      license = card(registration, event.ce_hours_details_label)
      expect(license.subtitle).to eq("6 hours")
      expect(license.badge).to eq("$150 · License number needed")
      expect(license.badge_classes).to be_nil

      registration.update!(ce_hours_requested: nil, ce_license_number: "LIC123")
      expect(card(registration, event.ce_hours_details_label).badge).to eq("Hours needed")

      registration.update!(ce_hours_requested: 6, ce_license_number: "LIC123")
      complete = card(registration, event.ce_hours_details_label)
      expect(complete.subtitle).to eq("6 hours")
      expect(complete.badge).to eq("$150 due")
      expect(complete.badge_classes).to include("teal")
    end

    it "shows the scholarship card only when requested, without an amount chip until awarded" do
      expect(card_titles(registration)).not_to include("Scholarship")
      registration.update!(scholarship_requested: true)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.subtitle).to eq("Your scholarship request status")
      expect(scholarship_card.badge).to be_nil
    end

    it "flags an awarded scholarship with outstanding tasks in an amber chip" do
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: false)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.badge).to eq("$250 · Tasks outstanding")
      expect(scholarship_card.badge_classes).to be_nil
    end

    it "shows a fuchsia amount chip once scholarship tasks are complete" do
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.badge).to eq("$250")
      expect(scholarship_card.badge_classes).to include("fuchsia")
    end

    it "places payment first and FAQ last in the full ordering" do
      event.update!(event_details: "Bring supplies", ce_hours_details: "6 hours",
                    videoconference_url: "https://example.zoom.us/j/123",
                    start_date: 3.days.ago, end_date: 2.days.ago)
      registration.update!(status: "attended", scholarship_requested: true, ce_credit_requested: true)
      expect(card_titles(registration)).to eq([
        "Make your payment",
        "Certificate of completion",
        "Scholarship",
        event.ce_hours_details_label,
        event.event_details_label,
        "Videoconference",
        "Forms",
        "Handouts",
        "Frequently asked questions"
      ])
    end
  end
end
