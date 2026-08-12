require "rails_helper"

RSpec.describe BuiltinCalloutCards do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }

  def card_titles(reg)
    described_class.new(reg).cards.map(&:title)
  end

  def card(reg, title)
    described_class.new(reg).cards.find { |c| c.title == title }
  end

  def add_scholarship_form(event)
    create(:event_form, :scholarship, event:)
  end

  describe "#cards" do
    it "shows the staff card only once the event has connected staff" do
      # An empty roster is nothing to link to, so the staff card gates on the event
      # having staff — like every other fallback card gates on its own config.
      expect(card_titles(registration)).to eq([ "Make your payment" ])

      create(:event_staff, event:)
      expect(card_titles(registration)).to eq([ "Make your payment", "Meet the staff" ])
    end

    it "omits the payment card for a free event" do
      event.update!(cost_cents: 0)
      expect(card_titles(registration)).not_to include("Payment")
    end

    it "never surfaces the row-driven Handouts or FAQ cards in the code fallback" do
      # These are admin-published now — there's no code fallback for them, even on
      # a facilitator training.
      event.update!(facilitator_training: true)
      expect(card_titles(registration)).not_to include("Handouts", "Frequently asked questions")
    end

    it "skips a built-in card the event has materialized (it renders from the row instead)" do
      event.update!(ce_hours_offered: 6)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE hours")

      # Materialized, so the code fallback omits it — the row renders it instead.
      expect(card_titles(registration.reload)).not_to include("CE hours")
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

    it "appends the ticket payment deadline to the due badge when the event sets one" do
      event.update!(payment_due_deadline: Time.zone.local(2026, 4, 9, 17, 0))
      due = card(registration, "Make your payment")
      expect(due.badge).to eq("$10.99 due by Apr 9")
    end

    it "shows a plain due badge when the event sets no payment deadline" do
      event.update!(payment_due_deadline: nil)
      due = card(registration, "Make your payment")
      expect(due.badge).to eq("$10.99 due")
    end

    it "uses the arrow trailing icon for every card" do
      event.update!(videoconference_url: "https://example.zoom.us/j/1")
      trailing = described_class.new(registration).cards.map(&:trailing_icon).uniq
      expect(trailing).to eq([ "fa-solid fa-arrow-right" ])
    end

    it "shows the certificate card in the fallback set only once it is available" do
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

    it "shows the CE card once the registrant has requested CE credit" do
      event.update!(ce_hours_offered: 6)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card_titles(registration.reload)).to include(event.ce_hours_label)
    end

    it "invites a not-yet-requested registrant to request CE while the window is open" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 15_000, ce_hours_request_deadline: Date.current + 1.day)
      invite = card(registration, event.ce_hours_label)
      expect(invite.subtitle).to eq("Request continuing education credit")
      expect(invite.badge).to eq("Request CE by #{(Date.current + 1.day).strftime("%b %-d")}")
      expect(invite.theme).to eq(DomainTheme.swatch("teal"))
    end

    it "invites a not-yet-requested registrant when the event sets no request deadline" do
      event.update!(ce_hours_offered: 6)
      expect(card_titles(registration)).to include(event.ce_hours_label)
    end

    it "stops inviting once the CE request deadline has passed" do
      event.update!(ce_hours_offered: 6, ce_hours_request_deadline: Date.current - 1.day)
      expect(card_titles(registration)).not_to include(event.ce_hours_label)
    end

    it "omits the CE card when the event offers no CE hours, even with a CE registration" do
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card_titles(registration.reload)).not_to include(event.ce_hours_label)
    end

    it "omits the scholarship card when the event has no scholarship form, even when requested" do
      registration.update!(scholarship_requested: true)
      expect(card_titles(registration)).not_to include("Scholarship")
    end

    it "renders scholarship + CE cards in preview even when the event isn't configured for them" do
      # No scholarship form and no CE hours, so config_gap would hide both on a real
      # ticket; the sample-ticket preview illustrates the registrant's options instead.
      registration.update!(scholarship_requested: true)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)

      preview_titles = described_class.new(registration.reload, preview: true).cards.map(&:title)
      expect(preview_titles).to include("Scholarship", event.ce_hours_label)
    end

    it "turns the CE card orange while a balance is due, teal once paid" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 15_000)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      ce = create(:continuing_education_registration, event_registration: registration, professional_license: license)

      # Balance due, license still needed: orange card, amber chip naming what's needed.
      needs = card(registration.reload, event.ce_hours_label)
      expect(needs.theme).to eq(DomainTheme.swatch("orange"))
      expect(needs.subtitle).to eq("6 hours")
      expect(needs.badge).to eq("$150 · License number needed")
      expect(needs.badge_classes).to be_nil

      # License provided but still owing: orange card, amber "$X due" chip like the payment card.
      license.update!(number: "LIC123")
      due = card(registration.reload, event.ce_hours_label)
      expect(due.theme).to eq(DomainTheme.swatch("orange"))
      expect(due.badge).to eq("$150 due")
      expect(due.badge_classes).to be_nil

      # Paid in full: resting teal card, no "due" chip.
      create(:allocation, allocatable: ce, amount: 15_000)
      paid = card(registration.reload, event.ce_hours_label)
      expect(paid.theme).to eq(DomainTheme.swatch("teal"))
      expect(paid.badge).to be_nil
    end

    it "names the CE request deadline on the license-needed badge" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 15_000, ce_hours_request_deadline: Date.new(2026, 7, 1))
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card(registration.reload, event.ce_hours_label).badge).to eq("$150 · License number needed by Jul 1")
    end

    it "appends the CE payment deadline to the amount-due badge, dropping it once paid" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 15_000, ce_payment_due_deadline: Date.new(2026, 8, 15))
      license = create(:professional_license, person: registration.registrant, number: "LIC123")
      ce_reg = create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card(registration.reload, event.ce_hours_label).badge).to eq("$150 due by Aug 15")

      create(:allocation, source: create(:payment), allocatable: ce_reg, amount: ce_reg.cost_cents)
      expect(card(registration.reload, event.ce_hours_label).badge).to be_nil
    end

    it "shows the scholarship card only when requested, without an amount chip until awarded" do
      add_scholarship_form(event)
      expect(card_titles(registration)).not_to include("Scholarship")
      registration.update!(scholarship_requested: true)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.subtitle).to eq("Your scholarship request status")
      expect(scholarship_card.badge).to be_nil
      expect(scholarship_card.theme).to eq(DomainTheme.swatch(DomainTheme.color_for(:scholarships)))
    end

    it "prompts to accept the agreement, without an amount chip, until it is signed" do
      add_scholarship_form(event)
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: true, agreement_signed: false)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.subtitle).to eq("Review and accept your scholarship agreement")
      expect(scholarship_card.badge).to be_nil
      expect(scholarship_card.theme).to eq(DomainTheme.swatch("amber"))
    end

    it "turns the scholarship card amber while award tasks are outstanding" do
      add_scholarship_form(event)
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, recipient: registration.registrant, tasks_completed: false, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)

      expect(card(registration, "Scholarship").theme).to eq(DomainTheme.swatch("amber"))
    end

    it "flags an awarded scholarship with outstanding tasks in an amber chip" do
      add_scholarship_form(event)
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: false, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.badge).to eq("$250 · Tasks outstanding")
      expect(scholarship_card.badge_classes).to be_nil
    end

    it "shows a fuchsia amount chip once the agreement is signed and tasks are complete" do
      add_scholarship_form(event)
      registration.update!(scholarship_requested: true)
      scholarship = create(:scholarship, amount_cents: 25_000, tasks_completed: true, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1000)
      scholarship_card = card(registration, "Scholarship")
      expect(scholarship_card.badge).to eq("$250")
      expect(scholarship_card.badge_classes).to include("fuchsia")
    end

    it "orders the code-fallback cards from payment downward" do
      # Handouts/FAQ/art supplies are row-driven, so they never appear in this fallback.
      event.update!(facilitator_training: true, ce_hours_offered: 6,
                    videoconference_url: "https://example.zoom.us/j/123",
                    start_date: 3.days.ago, end_date: 2.days.ago)
      add_scholarship_form(event)
      create(:event_staff, event:)
      registration.update!(status: "attended", scholarship_requested: true)
      license = create(:professional_license, :placeholder, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      expect(card_titles(registration)).to eq([
        "Make your payment",
        "Scholarship",
        event.ce_hours_label,
        "Videoconference",
        "Meet the staff",
        "Certificate of completion"
      ])
    end
  end

  describe "#card_for" do
    it "uses the row's editable presentation (title/subtitle/colour) but the app's live badge/link" do
      # Videoconference isn't app-coloured, so the row's colour is honoured.
      event.update!(videoconference_url: "https://example.com/z")
      callout = create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        title: "Your documents", subtitle: "Downloads", color_class: "green")

      card = described_class.new(registration).card_for(callout)
      expect(card.title).to eq("Your documents")         # from the row
      expect(card.subtitle).to eq("Downloads")           # from the row
      expect(card.theme).to eq(DomainTheme.swatch("green")) # from the row
    end

    it "keeps Payment's live-status colour, overriding the selected colour" do
      event.update!(cost_cents: 5_000)
      callout = create(:registration_ticket_callout, event:, builtin_key: "payment",
        title: "Pay your balance", color_class: "green")

      card = described_class.new(registration).card_for(callout)
      expect(card.title).to eq("Pay your balance")          # row still owns text
      expect(card.theme).to eq(DomainTheme.swatch("orange")) # app colour (balance due), not green
      expect(card.badge).to end_with("due")
    end

    it "badges a materialized certificate row as pending until it unlocks" do
      callout = create(:registration_ticket_callout, event:, builtin_key: "certificate",
        title: "Certificate of completion")

      # Certificate isn't unlocked (event not ended, not attended), but the card
      # still shows so the registrant knows one is coming — badged as pending.
      card = described_class.new(registration).card_for(callout)
      expect(card).to be_present
      expect(card.badge).to eq("Available after the event")
    end

    it "returns nil for a behavioral card that truly can't apply (no videoconference URL)" do
      callout = create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        title: "Videoconference")

      expect(described_class.new(registration).card_for(callout)).to be_nil
    end

    it "links the staff card to the registrant's roster page, keeping the row's text" do
      create(:event_staff, event:)
      callout = create(:registration_ticket_callout, event:, builtin_key: "staff",
        title: "Meet our team", subtitle: "Who you'll learn from")

      card = described_class.new(registration).card_for(callout)
      expect(card.title).to eq("Meet our team")            # row owns the text
      expect(card.href).to eq("/registration/#{registration.slug}/staff")
    end

    it "returns nil for a materialized staff row when the event has no staff" do
      callout = create(:registration_ticket_callout, event:, builtin_key: "staff",
        title: "Meet the staff")

      expect(described_class.new(registration).card_for(callout)).to be_nil
    end

    it "keeps the live CE deadline badge on a materialized CE row" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 15_000, ce_payment_due_deadline: Date.new(2026, 8, 15))
      license = create(:professional_license, person: registration.registrant, number: "LIC123")
      create(:continuing_education_registration, event_registration: registration, professional_license: license)
      callout = create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE credit")

      card = described_class.new(registration.reload).card_for(callout)
      expect(card.title).to eq("CE credit")            # row owns the text
      expect(card.badge).to eq("$150 due by Aug 15")   # app keeps the live deadline badge
    end
  end
end
