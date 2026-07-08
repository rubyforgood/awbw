require "rails_helper"

RSpec.describe DefaultTicketCallouts do
  describe "#seed" do
    it "materializes the Handouts, FAQ, and Certificate magic callouts" do
      event = create(:event)

      described_class.seed(event)

      keys = event.registration_ticket_callouts.magic.pluck(:magic_key)
      expect(keys).to contain_exactly("handouts", "faq", "certificate")
    end

    it "seeds the Videoconference card, dripping a week before start, only once the event has a link" do
      event = create(:event, start_date: Date.new(2026, 9, 10))
      described_class.seed(event)
      expect(event.registration_ticket_callouts.find_by(magic_key: "videoconference")).to be_nil

      event.update!(videoconference_url: "https://example.com/zoom")
      described_class.seed(event)

      vc = event.registration_ticket_callouts.find_by(magic_key: "videoconference")
      expect(vc.display_from.to_date).to eq(Date.new(2026, 9, 3))
      expect(vc.hidden).to be(false)
    end

    it "defaults Certificate off for a non-training event and on for a facilitator training" do
      non_training = create(:event, facilitator_training: false)
      training = create(:event, facilitator_training: true)

      described_class.seed(non_training)
      described_class.seed(training)

      expect(non_training.registration_ticket_callouts.find_by(magic_key: "certificate").hidden).to be(true)
      expect(training.registration_ticket_callouts.find_by(magic_key: "certificate").hidden).to be(false)
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
      expect(event.registration_ticket_callouts.ordered.map(&:magic_key).compact).to eq(%w[handouts faq certificate])
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
