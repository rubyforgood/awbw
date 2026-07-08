require "rails_helper"

RSpec.describe DefaultTicketCallouts do
  describe "#seed" do
    it "materializes the Handouts and FAQ magic callouts" do
      event = create(:event)

      described_class.seed(event)

      keys = event.registration_ticket_callouts.magic.pluck(:magic_key)
      expect(keys).to contain_exactly("handouts", "faq")
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
      expect(event.registration_ticket_callouts.ordered.map(&:magic_key).compact).to eq(%w[handouts faq])
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
