require "rails_helper"

RSpec.describe BuiltinCallouts do
  describe "#build" do
    it "builds the built-ins as unsaved in-memory rows on a new event" do
      event = Event.new

      built = described_class.build(event)

      # No dates on a bare Event, so day_count is 1 and the Day 2 survey is skipped.
      expect(built.map(&:builtin_key)).to contain_exactly(
        "payment", "certificate", "scholarship", "ce_hours",
        "videoconference", "staff", "handouts", "faq",
        "day_1_survey", "scholarship_recipients_survey"
      )
      expect(built).to all(be_new_record)
      expect(event.registration_ticket_callouts).to match_array(built)
    end

    it "is idempotent — skips keys already present on the association" do
      event = create(:event)
      described_class.seed(event)

      built = described_class.build(event)

      expect(built).to be_empty
      # 8 originals + the 3 survey built-ins (the factory event spans multiple days).
      expect(event.registration_ticket_callouts.builtin.count).to eq(11)
    end

    it "builds a paid event's Payment card with the W-9 link (subtitle) in memory" do
      w9 = create(:resource, title: "W-9")
      event = Event.new(cost_cents: 5_000)

      described_class.build(event)

      payment = event.registration_ticket_callouts.find { |c| c.builtin_key == "payment" }
      link = payment.registration_ticket_callout_resources.find { |r| r.resource == w9 }
      expect(link).to be_present
      expect(link.subtitle).to eq("AWBW's W-9 tax form for your records")
    end
  end

  describe "#seed" do
    it "materializes the built-in callouts for every event" do
      event = create(:event, cost_cents: 0) # free, no scholarship form, no VC link

      described_class.seed(event)

      keys = event.registration_ticket_callouts.builtin.pluck(:builtin_key)
      expect(keys).to contain_exactly(
        "payment", "certificate", "scholarship", "ce_hours",
        "videoconference", "staff", "handouts", "faq",
        "day_1_survey", "day_2_survey", "scholarship_recipients_survey"
      )
    end

    it "seeds callouts in canonical ticket order" do
      form = create(:form)
      event = create(:event, facilitator_training: true, ce_hours_offered: 6,
        videoconference_url: "https://example.com/z")
      event.event_forms.create!(form:, role: "scholarship")

      described_class.seed(event)

      expect(event.registration_ticket_callouts.ordered.map(&:builtin_key)).to eq(
        %w[payment scholarship ce_hours videoconference staff handouts certificate faq day_1_survey day_2_survey scholarship_recipients_survey]
      )
    end

    it "seeds the Videoconference card with a drip date a week before start" do
      event = create(:event, start_date: Date.new(2026, 9, 10), end_date: Date.new(2026, 9, 12))
      described_class.seed(event)

      vc = event.registration_ticket_callouts.find_by(builtin_key: "videoconference")
      expect(vc).to be_present
      expect(vc.display_from.to_date).to eq(Date.new(2026, 9, 3))
      expect(vc.hidden).to be(true) # non-training: hidden by default
    end

    it "hides every callout by default, regardless of facilitator training" do
      non_training = create(:event, cost_cents: 0)
      training = create(:event, :publicly_visible, facilitator_training: true, cost_cents: 100,
        videoconference_url: "https://example.com/vc")

      described_class.seed(non_training)
      described_class.seed(training)

      [ non_training, training ].each do |event|
        event.registration_ticket_callouts.builtin.each do |callout|
          expect(callout.hidden).to be(true), "expected #{callout.builtin_key} hidden by default"
        end
      end
    end

    it "links the W-9 to the Payment card as a removable resource on paid events" do
      w9 = create(:resource, title: "W-9")
      event = create(:event) # paid by factory, so the W-9 seeds

      described_class.seed(event)

      payment = event.registration_ticket_callouts.find_by(builtin_key: "payment")
      expect(payment.resources).to eq([ w9 ])
    end

    it "links the W-9 to the Payment card on a free event too (dormant until it's priced)" do
      w9 = create(:resource, title: "W-9")
      event = create(:event, facilitator_training: true, cost_cents: 0)

      described_class.seed(event)

      payment = event.registration_ticket_callouts.find_by(builtin_key: "payment")
      expect(payment).to be_present
      # The link is always present; the payment surface (and this document) only
      # renders once the event has a cost, so free→paid needs no backfill.
      expect(payment.resources).to eq([ w9 ])
    end

    it "seeds CE hours with its default title and no content" do
      event = create(:event)

      described_class.seed(event)

      ce = event.registration_ticket_callouts.find_by(builtin_key: "ce_hours")
      expect(ce.title).to eq("CE hours")
      expect(ce.description).to be_blank
      # A freshly-seeded card matches its default.
      expect(described_class.customized?(ce)).to be(false)
    end

    it "seeds Handouts as a content callout" do
      event = create(:event)

      described_class.seed(event)

      handouts = event.registration_ticket_callouts.find_by(builtin_key: "handouts")
      expect(handouts.behavioral_builtin?).to be(false)
    end

    it "reports whether a materialized callout has been customized" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")

      expect(described_class.customized?(faq)).to be(false)

      faq.update!(title: "Our questions")
      expect(described_class.customized?(faq)).to be(true)

      described_class.reset(faq)
      expect(described_class.customized?(faq.reload)).to be(false)
    end

    it "treats a changed drip display date as customized" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")

      expect(described_class.customized?(faq)).to be(false)

      faq.update!(display_from: Date.new(2026, 8, 1))
      expect(described_class.customized?(faq)).to be(true)

      described_class.reset(faq)
      expect(described_class.customized?(faq.reload)).to be(false)
    end

    it "seeds the FAQ card with the default training content" do
      event = create(:event)

      described_class.seed(event)

      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")
      expect(faq.description).to include("Who is this training designed for?")
      expect(faq.callout_type).to eq("reference")
    end

    it "links the handout worksheet resources in display order" do
      first = create(:resource, title: "2-Day AWBW Facilitator Training Worksheets & Handouts")
      second = create(:resource, title: "AWBW Training Workshop Worksheets")
      event = create(:event)

      described_class.seed(event)

      handouts = event.registration_ticket_callouts.find_by(builtin_key: "handouts")
      expect(handouts.resources).to eq([ first, second ])
    end

    it "materializes each handout link's default subtitle and page content" do
      title = "Aha Moments"
      create(:resource, title: title)
      event = create(:event)

      described_class.seed(event)

      handouts = event.registration_ticket_callouts.find_by(builtin_key: "handouts")
      link = handouts.registration_ticket_callout_resources.joins(:resource).find_by(resources: { title: })
      defaults = BuiltinCallouts::HANDOUT_LINK_DEFAULTS[title]
      expect(link.subtitle).to eq(defaults[:subtitle])
      expect(link.page_content).to eq(defaults[:page_content])
    end

    it "flags edited link copy as customized and restores it on reset" do
      create(:resource, title: "Aha Moments")
      event = create(:event)
      described_class.seed(event)
      handouts = event.registration_ticket_callouts.find_by(builtin_key: "handouts")
      expect(described_class.customized?(handouts)).to be(false)

      handouts.registration_ticket_callout_resources.first.update!(subtitle: "Edited")
      expect(described_class.customized?(handouts.reload)).to be(true)

      described_class.reset(handouts)
      expect(described_class.customized?(handouts.reload)).to be(false)
    end

    it "hides Handouts and FAQ by default (no config signal auto-publishes them)" do
      event = create(:event, facilitator_training: true)

      described_class.seed(event)

      expect(event.registration_ticket_callouts.where(builtin_key: %w[handouts faq]).pluck(:hidden)).to all(be(true))
    end

    it "is idempotent and never clobbers an existing built-in callout" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")
      faq.update!(description: "<p>Custom answer.</p>", hidden: true)

      expect { described_class.seed(event) }.not_to change { event.registration_ticket_callouts.count }
      expect(faq.reload.description).to eq("<p>Custom answer.</p>")
      expect(faq.hidden).to be(true)
    end

    it "skips a built-in when the DB unique index rejects a concurrent duplicate" do
      event = create(:event, cost_cents: 0)
      service = described_class.new(event)

      # Simulate the concurrency window: the in-memory existence + uniqueness
      # checks pass, but the unique index on [event_id, builtin_key] rejects the
      # insert because a concurrent request committed the same row first. Fire it
      # for Handouts, mirroring the Honeybadger report.
      original_create = event.registration_ticket_callouts.method(:create!)
      allow(event.registration_ticket_callouts).to receive(:create!) do |attrs|
        raise ActiveRecord::RecordNotUnique, "Duplicate entry" if attrs[:builtin_key] == "handouts"
        original_create.call(attrs)
      end

      expect { service.seed }.not_to raise_error

      keys = event.registration_ticket_callouts.builtin.pluck(:builtin_key)
      expect(keys).to contain_exactly(
        "payment", "certificate", "scholarship", "ce_hours",
        "videoconference", "staff", "faq",
        "day_1_survey", "day_2_survey", "scholarship_recipients_survey"
      )
    end

    it "appends the built-in callouts after existing custom ones" do
      event = create(:event)
      custom = create(:registration_ticket_callout, event:, title: "Parking")

      described_class.seed(event)

      expect(event.registration_ticket_callouts.ordered.first).to eq(custom)
      expect(event.registration_ticket_callouts.ordered.map(&:builtin_key).compact).to eq(
        %w[payment scholarship ce_hours videoconference staff handouts certificate faq day_1_survey day_2_survey scholarship_recipients_survey]
      )
    end
  end

  describe ".reset" do
    it "restores an edited built-in callout's content, resources, and visibility to default" do
      resource = create(:resource, title: "AWBW Training Workshop Worksheets")
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")
      faq.update!(title: "Custom", description: "<p>Edited</p>", hidden: false)
      faq.resources << resource

      described_class.reset(faq)

      expect(faq.reload.title).to eq("Frequently asked questions")
      expect(faq.description).to include("Who is this training designed for?")
      expect(faq.hidden).to be(true)
      expect(faq.resources).to be_empty
    end

    it "keeps the callout's position when restoring" do
      event = create(:event, facilitator_training: true)
      described_class.seed(event)
      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")
      original_position = faq.position

      described_class.reset(faq)

      expect(faq.reload.position).to eq(original_position)
    end

    it "leaves a custom callout untouched" do
      callout = create(:registration_ticket_callout, title: "Parking", builtin_key: nil)

      expect { described_class.reset(callout) }.not_to change { callout.reload.title }
    end
  end

  describe "post-event survey built-ins" do
    it "seeds the Day 1 and scholarship surveys but omits Day 2 on a one-day event" do
      event = create(:event, start_date: Time.zone.local(2026, 9, 10, 9), end_date: Time.zone.local(2026, 9, 10, 17))

      described_class.seed(event)

      keys = event.registration_ticket_callouts.builtin.pluck(:builtin_key)
      expect(keys).to include("day_1_survey", "scholarship_recipients_survey")
      expect(keys).not_to include("day_2_survey")
    end

    it "seeds the Day 2 survey on a multi-day event" do
      event = create(:event, start_date: Time.zone.local(2026, 9, 10, 9), end_date: Time.zone.local(2026, 9, 11, 17))

      described_class.seed(event)

      expect(event.registration_ticket_callouts.pluck(:builtin_key)).to include("day_2_survey")
    end

    it "points each survey callout at its seeded template form" do
      day_1_form = FormBuilderService.new(name: "Day 1 Survey", sections: [ :day_1_survey ], role: "day_1_survey").call
      event = create(:event)

      described_class.seed(event)

      callout = event.registration_ticket_callouts.find_by(builtin_key: "day_1_survey")
      expect(callout.form).to eq(day_1_form)
    end

    it "drips the Day 1 survey 30 minutes before that day's end time" do
      event = create(:event, start_date: Time.zone.local(2026, 9, 10, 9), end_date: Time.zone.local(2026, 9, 11, 17))

      described_class.seed(event)

      day_1 = event.registration_ticket_callouts.find_by(builtin_key: "day_1_survey")
      expect(day_1.display_from).to eq(Time.zone.local(2026, 9, 10, 16, 30))
    end

    it "drips the scholarship survey 30 minutes before the event ends" do
      event = create(:event, end_date: Time.zone.local(2026, 9, 11, 17))

      described_class.seed(event)

      scholarship = event.registration_ticket_callouts.find_by(builtin_key: "scholarship_recipients_survey")
      expect(scholarship.display_from).to eq(Time.zone.local(2026, 9, 11, 16, 30))
    end
  end
end
