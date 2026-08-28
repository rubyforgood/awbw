# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimelineServices::RecordEvent do
  let(:holder_class) do
    stub_const("SpecTimelineHolder", Class.new(ApplicationRecord) do
      self.table_name = "people"
      include HasTimeline
      include Timelineable

      def timeline_label
        "#{first_name} #{last_name}"
      end
    end)
  end

  let(:holder) { holder_class.find(create(:person).id) }
  let(:other_holder) { holder_class.find(create(:person).id) }

  around do |example|
    Current.reset
    example.run
    Current.reset
  end

  describe ".call" do
    it "creates the event and places it in the subject's timeline" do
      event = described_class.call(subject: holder, action: "created")

      expect(event).to be_persisted
      expect(event.action).to eq("created")
      expect(event.subject).to eq(holder)
      expect(event.timeline_entries.count).to eq(1)
      expect(event.timeline_entries.first.owner).to eq(holder)
    end

    it "places an event on a timeline through the association" do
      event = TimelineEvent.create!(
        subject: holder,
        action: "created",
        snapshot: { "subject_label" => holder.timeline_label }
      )

      holder.timeline_events << event

      expect(holder.timeline_events).to contain_exactly(event)
      expect(event.timeline_entries.first.owner).to eq(holder)
      expect {
        holder.timeline_events << event
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "records timeline events from both concern and model after_create callbacks" do
          tracked_class = stub_const("SpecTrackedSubject", Class.new(ApplicationRecord) do
            self.table_name = "people"
            include HasTimeline
            include Timelineable

            after_create -> { TimelineServices::RecordEvent.call(subject: self, action: "created") }
          end)

          record = tracked_class.create!(first_name: "Once", last_name: "Only")

          expect(record.timeline_entries.count).to eq(2)
        end

    it "generates the subject label on the fly" do
      event = described_class.call(subject: holder, action: "created")

      expect(event.subject&.timeline_label).to eq(holder.timeline_label)
    end

    it "lets caller snapshot fields win over generated ones" do
      event = described_class.call(
        subject: holder,
        action: "reminder_sent",
        snapshot: { "count" => 40 }
      )

      expect(event.snapshot["count"]).to eq(40)
    end

    it "attributes the actor" do
      admin = create(:user, :admin)

      event = described_class.call(subject: holder, action: "updated", actor: admin)

      expect(event.actor).to eq(admin)
      expect(event.actor_label).to eq(admin.full_name)
    end

    it "labels a userless actor from Current.source" do
      Current.source = "public_registration"

      event = described_class.call(subject: holder, action: "created", actor: nil)

      expect(event.actor).to be_nil
      expect(event.actor_label).to eq("A Registration Form Submission")
    end

    it "adds also_log targets without duplicating any timeline" do
      event = described_class.call(
        subject: holder,
        action: "payment_received",
        also_log: [ other_holder, other_holder ]
      )

      expect(event.timeline_entries.map(&:owner)).to contain_exactly(holder, other_holder)
    end

    it "raises when no target exists for the subject" do
      bare_subject_class = stub_const("SpecBareTimelineSubject", Class.new(ApplicationRecord) do
        self.table_name = "people"
        include Timelineable
      end)
      bare_subject = bare_subject_class.find(create(:person).id)

      expect {
        described_class.call(subject: bare_subject, action: "created")
      }.to raise_error(ArgumentError, /no timeline target/i)
    end

    it "rolls back the event when an entry fails" do
      bogus = Struct.new(:name).new("Bogus")

      expect {
        described_class.call(subject: holder, action: "created", also_log: [ bogus ])
      }.to raise_error(StandardError)
    end

    it "writes nothing and returns nil while suppressed" do
      result = described_class.suppress do
        described_class.call(subject: holder, action: "created")
      end

      expect(result).to be_nil
      expect(TimelineEvent.count).to eq(0)
      expect(TimelineEntry.count).to eq(0)
    end

    it "restores suppression state after nesting" do
      described_class.suppress do
        described_class.suppress { }
        expect(described_class.suppressed?).to be(true)
      end

      expect(described_class.suppressed?).to be(false)
    end
  end
end
