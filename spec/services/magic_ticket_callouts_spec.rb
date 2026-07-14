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
    it "shows the payment card for a bare paid, non-training registration" do
      expect(card_titles(registration)).to eq([ "Make your payment" ])
    end

    it "omits the payment card for a free event" do
      event.update!(cost_cents: 0)
      expect(card_titles(registration)).not_to include("Payment")
    end

    it "shows Handouts and FAQ only for facilitator trainings" do
      expect(card_titles(registration)).not_to include("Handouts", "Frequently asked questions")

      event.update!(facilitator_training: true)
      expect(card_titles(registration)).to include("Handouts", "Frequently asked questions")
    end

    it "skips a built-in card the event has materialized (it renders from the row instead)" do
      event.update!(facilitator_training: true)
      create(:registration_ticket_callout, event:, magic_key: "faq", title: "Frequently asked questions")

      # No duplicate FAQ from the code path; Handouts (not materialized) still renders here.
      titles = card_titles(registration)
      expect(titles.count("Frequently asked questions")).to eq(0)
      expect(titles).to include("Handouts")
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
      expect(card_titles(registration)).not_to include(event.ce_hours_details_label)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card_titles(registration.reload)).to include(event.ce_hours_details_label)
    end

    it "turns the CE card orange while a balance is due, teal once paid" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 15_000)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      ce = create(:continuing_education_registration, event_registration: registration, professional_license: license)

      # Balance due, license still needed: orange card, amber chip naming what's needed.
      needs = card(registration.reload, event.ce_hours_details_label)
      expect(needs.theme).to eq(DomainTheme.swatch("orange"))
      expect(needs.subtitle).to eq("6 hours")
      expect(needs.badge).to eq("$150 · License number needed")
      expect(needs.badge_classes).to be_nil

      # License provided but still owing: orange card, amber "$X due" chip like the payment card.
      license.update!(number: "LIC123")
      due = card(registration.reload, event.ce_hours_details_label)
      expect(due.theme).to eq(DomainTheme.swatch("orange"))
      expect(due.badge).to eq("$150 due")
      expect(due.badge_classes).to be_nil

      # Paid in full: resting teal card, no "due" chip.
      create(:allocation, allocatable: ce, amount: 15_000)
      paid = card(registration.reload, event.ce_hours_details_label)
      expect(paid.theme).to eq(DomainTheme.swatch("teal"))
      expect(paid.badge).to be_nil
    end

    it "shows the scholarship card only when requested, without an amount chip until awarded" do
      expect(card_titles(registration)).not_to include("Scholarship")
      registration.update!(scholarship_requested: true)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.subtitle).to eq("Your scholarship request status")
      expect(scholarship_card.badge).to be_nil
      expect(scholarship_card.theme).to eq(DomainTheme.swatch(DomainTheme.color_for(:scholarships)))
    end

    it "prompts to accept the agreement, without an amount chip, until it is signed" do
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: true, agreement_signed: false)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.subtitle).to eq("Review and accept your scholarship agreement")
      expect(scholarship_card.badge).to be_nil
      expect(scholarship_card.theme).to eq(DomainTheme.swatch("amber"))
    end

    it "turns the scholarship card amber while award tasks are outstanding" do
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, recipient: registration.registrant, tasks_completed: false, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)

      expect(card(registration, "Scholarship").theme).to eq(DomainTheme.swatch("amber"))
    end

    it "flags an awarded scholarship with outstanding tasks in an amber chip" do
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: false, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.badge).to eq("$250 · Tasks outstanding")
      expect(scholarship_card.badge_classes).to be_nil
    end

    it "shows a fuchsia amount chip once the agreement is signed and tasks are complete" do
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: true, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.badge).to eq("$250")
      expect(scholarship_card.badge_classes).to include("fuchsia")
    end

    it "places payment first and FAQ last in the full ordering" do
      event.update!(facilitator_training: true, event_details: "Bring supplies",
                    ce_hours_details: "6 hours", ce_hours_offered: 6,
                    videoconference_url: "https://example.zoom.us/j/123",
                    start_date: 3.days.ago, end_date: 2.days.ago)
      registration.update!(status: "attended", scholarship_requested: true)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card_titles(registration)).to eq([
        "Make your payment",
        "Certificate of completion",
        "Scholarship",
        event.ce_hours_details_label,
        event.event_details_label,
        "Videoconference",
        "Handouts",
        "Frequently asked questions"
      ])
    end
  end

  describe "#card_for" do
    it "uses the row's editable presentation (title/subtitle/colour) but the app's live badge/link" do
      # Videoconference isn't app-coloured, so the row's colour is honoured.
      event.update!(videoconference_url: "https://example.com/z")
      callout = create(:registration_ticket_callout, event:, magic_key: "videoconference",
        title: "Your documents", subtitle: "Downloads", color_class: "green")

      card = described_class.new(registration).card_for(callout)
      expect(card.title).to eq("Your documents")         # from the row
      expect(card.subtitle).to eq("Downloads")           # from the row
      expect(card.theme).to eq(DomainTheme.swatch("green")) # from the row
    end

    it "keeps Payment's live-status colour, overriding the selected colour" do
      event.update!(cost_cents: 5_000)
      callout = create(:registration_ticket_callout, event:, magic_key: "payment",
        title: "Pay your balance", color_class: "green")

      card = described_class.new(registration).card_for(callout)
      expect(card.title).to eq("Pay your balance")          # row still owns text
      expect(card.theme).to eq(DomainTheme.swatch("orange")) # app colour (balance due), not green
      expect(card.badge).to end_with("due")
    end

    it "returns nil when the card shouldn't show for this registration" do
      callout = create(:registration_ticket_callout, event:, magic_key: "certificate",
        title: "Certificate of completion")

      # Certificate isn't unlocked (event not ended, not attended).
      expect(described_class.new(registration).card_for(callout)).to be_nil
    end
  end
end
