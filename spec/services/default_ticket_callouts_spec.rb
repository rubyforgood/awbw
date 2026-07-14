require "rails_helper"

RSpec.describe DefaultTicketCallouts do
  describe "#seed" do
    it "materializes all eight built-in callouts for every event" do
      event = create(:event, cost_cents: 0) # free, no scholarship form, no VC link

      described_class.seed(event)

      keys = event.registration_ticket_callouts.magic.pluck(:magic_key)
      expect(keys).to contain_exactly(
        "payment", "certificate", "scholarship", "ce_hours", "event_details",
        "videoconference", "handouts", "faq"
      )
    end

    it "seeds callouts in canonical ticket order" do
      form = create(:form)
      event = create(:event, facilitator_training: true, ce_hours_offered: 6,
        event_details: "<p>x</p>", videoconference_url: "https://example.com/z")
      event.event_forms.create!(form:, role: "scholarship")

      described_class.seed(event)

      expect(event.registration_ticket_callouts.ordered.map(&:magic_key)).to eq(
        %w[payment certificate scholarship ce_hours event_details videoconference handouts faq]
      )
    end

    it "seeds the Videoconference card with a drip date a week before start" do
      event = create(:event, start_date: Date.new(2026, 9, 10))
      described_class.seed(event)

      vc = event.registration_ticket_callouts.find_by(magic_key: "videoconference")
      expect(vc).to be_present
      expect(vc.display_from.to_date).to eq(Date.new(2026, 9, 3))
      expect(vc.hidden).to be(true) # non-training: hidden by default
    end

    it "hides all callouts by default on a non-training event, shows all on a facilitator training" do
      form = create(:form)
      non_training = create(:event, cost_cents: 0)
      non_training.event_forms.create!(form:, role: "scholarship")
      training = create(:event, :publicly_visible, facilitator_training: true, cost_cents: 100,
        videoconference_url: "https://example.com/vc")
      training.event_forms.create!(form:, role: "scholarship")

      described_class.seed(non_training)
      described_class.seed(training)

      non_training.registration_ticket_callouts.magic.each do |callout|
        expect(callout.hidden).to be(true), "expected #{callout.magic_key} hidden on non-training"
      end
      training.registration_ticket_callouts.magic.each do |callout|
        expect(callout.hidden).to be(false), "expected #{callout.magic_key} visible on training"
      end
    end

    it "defaults Certificate off for a non-training event and on for a facilitator training" do
      non_training = create(:event, facilitator_training: false)
      training = create(:event, facilitator_training: true)

      described_class.seed(non_training)
      described_class.seed(training)

      expect(non_training.registration_ticket_callouts.find_by(magic_key: "certificate").hidden).to be(true)
      expect(training.registration_ticket_callouts.find_by(magic_key: "certificate").hidden).to be(false)
    end

    it "links the W-9 to the Payment card as a removable resource on paid events" do
      w9 = create(:resource, title: "W-9")
      event = create(:event) # paid by factory, so the W-9 seeds

      described_class.seed(event)

      payment = event.registration_ticket_callouts.find_by(magic_key: "payment")
      expect(payment.resources).to eq([ w9 ])
    end

    it "omits the W-9 from the Payment card on a free (training) event" do
      create(:resource, title: "W-9")
      event = create(:event, facilitator_training: true, cost_cents: 0)

      described_class.seed(event)

      payment = event.registration_ticket_callouts.find_by(magic_key: "payment")
      expect(payment).to be_present
      expect(payment.resources).to be_empty # no W-9 on a free event
    end

    it "migrates CE hours and event-details content from the event onto the row" do
      event = create(:event, ce_hours_details_label: "Continuing education",
        ce_hours_details: "<p>CAMFT approved.</p>", event_details_label: "Art supplies",
        event_details: "<p>Bring paper.</p>")

      described_class.seed(event)

      ce = event.registration_ticket_callouts.find_by(magic_key: "ce_hours")
      details = event.registration_ticket_callouts.find_by(magic_key: "event_details")
      expect(ce.title).to eq("Continuing education")
      expect(ce.description).to eq("<p>CAMFT approved.</p>")
      expect(details.title).to eq("Art supplies")
      expect(details.description).to eq("<p>Bring paper.</p>")
      # A freshly-migrated card matches its default.
      expect(described_class.customized?(ce)).to be(false)
    end

    it "reports whether a materialized callout has been customized" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")

      expect(described_class.customized?(faq)).to be(false)

      faq.update!(title: "Our questions")
      expect(described_class.customized?(faq)).to be(true)

      described_class.reset(faq)
      expect(described_class.customized?(faq.reload)).to be(false)
    end

    it "treats a changed drip display date as customized" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")

      expect(described_class.customized?(faq)).to be(false)

      faq.update!(display_from: Date.new(2026, 8, 1))
      expect(described_class.customized?(faq)).to be(true)

      described_class.reset(faq)
      expect(described_class.customized?(faq.reload)).to be(false)
    end

    it "seeds the FAQ card with the default training content" do
      event = create(:event)

      described_class.seed(event)

      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")
      expect(faq.description).to include("Who is this training designed for?")
      expect(faq.callout_type).to eq("reference")
    end

    it "links the handout worksheet resources in display order" do
      first = create(:resource, title: "2-Day AWBW Facilitator Training Worksheets & Handouts")
      second = create(:resource, title: "AWBW Training Workshop Worksheets")
      event = create(:event)

      described_class.seed(event)

      handouts = event.registration_ticket_callouts.find_by(magic_key: "handouts")
      expect(handouts.resources).to eq([ first, second ])
    end

    it "shows Handouts and FAQ by default on a facilitator training" do
      event = create(:event, facilitator_training: true)

      described_class.seed(event)

      expect(event.registration_ticket_callouts.where(magic_key: %w[handouts faq]).pluck(:hidden)).to all(be(false))
    end

    it "hides Handouts and FAQ by default on a non-training event" do
      event = create(:event, facilitator_training: false)

      described_class.seed(event)

      expect(event.registration_ticket_callouts.where(magic_key: %w[handouts faq]).pluck(:hidden)).to all(be(true))
    end

    it "is idempotent and never clobbers an existing magic callout" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")
      faq.update!(description: "<p>Custom answer.</p>", hidden: true)

      expect { described_class.seed(event) }.not_to change { event.registration_ticket_callouts.count }
      expect(faq.reload.description).to eq("<p>Custom answer.</p>")
      expect(faq.hidden).to be(true)
    end

    it "appends the magic callouts after existing custom ones" do
      event = create(:event)
      custom = create(:registration_ticket_callout, event:, title: "Parking")

      described_class.seed(event)

      expect(event.registration_ticket_callouts.ordered.first).to eq(custom)
      expect(event.registration_ticket_callouts.ordered.map(&:magic_key).compact).to eq(
        %w[payment certificate scholarship ce_hours event_details videoconference handouts faq]
      )
    end
  end

  describe ".reset" do
    it "restores an edited magic callout's content, resources, and visibility to default" do
      resource = create(:resource, title: "AWBW Training Workshop Worksheets")
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")
      faq.update!(title: "Custom", description: "<p>Edited</p>", hidden: true)
      faq.resources << resource

      described_class.reset(faq)

      expect(faq.reload.title).to eq("Frequently asked questions")
      expect(faq.description).to include("Who is this training designed for?")
      expect(faq.hidden).to be(false)
      expect(faq.resources).to be_empty
    end

    it "keeps the callout's position when restoring" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(magic_key: "faq")
      original_position = faq.position

      described_class.reset(faq)

      expect(faq.reload.position).to eq(original_position)
    end

    it "leaves a custom callout untouched" do
      callout = create(:registration_ticket_callout, title: "Parking", magic_key: nil)

      expect { described_class.reset(callout) }.not_to change { callout.reload.title }
    end
  end
end
