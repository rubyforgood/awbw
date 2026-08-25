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
  end
end
