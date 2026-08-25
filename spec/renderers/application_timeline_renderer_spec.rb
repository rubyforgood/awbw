# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationTimelineRenderer do
  describe "#label" do
    it "returns a link to the subject when persisted" do
      person = create(:person)
      event = TimelineServices::RecordEvent.call(subject: person, action: "created")
      renderer = described_class.new(event)

      output = renderer.label
      expect(output).to include(person.timeline_label)
    end

    it "returns nil when subject is not persisted" do
      person = build(:person)
      event = TimelineEvent.new(subject: person, action: "created", snapshot: { "changes" => {} })
      renderer = described_class.new(event)

      expect(renderer.label).to be_nil
    end

    it "renders snapshot label when subject is nil" do
      event = TimelineEvent.new(subject: nil, action: "destroyed", snapshot: { "label" => "Person: Alice" })
      renderer = described_class.new(event)

      output = renderer.label
      expect(output).to include("Person: Alice")
      expect(output).not_to include("href")
    end

    it "renders snapshot label for a deleted model whose class has a custom renderer" do
      scholarship = create(:scholarship)
      event = TimelineServices::RecordEvent.call(subject: scholarship, action: "created")

      snapshot_label = event.snapshot["label"]
      expect(snapshot_label).to include("Scholarship")

      scholarship.destroy!
      event.reload

      renderer = described_class.new(event)
      output = renderer.label

      expect(output).to include(snapshot_label)
      expect(output).not_to include("href")
    end

    it "uses ApplicationTimelineRenderer for a model without a custom renderer" do
      expect(Person.timeline_renderer_class).to eq(ApplicationTimelineRenderer)
    end
  end
end
