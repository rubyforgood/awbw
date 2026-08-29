# frozen_string_literal: true

require "rails_helper"

RSpec.describe NestedRecordTimelineRenderer do
  describe "#label" do
    it "links the persisted subject to the owner with on-context" do
      person = create(:person)
      item = create(:categorizable_item, categorizable: person)
      event = TimelineServices::RecordEvent.call(subject: item, action: "created")
      renderer = described_class.new(event, owner: person)

      output = renderer.label
      expect(output).to include("on #{person.timeline_label}")
      expect(output).to include("href")
    end

    it "renders the snapshot label with from-context for a destroyed subject" do
      person = create(:person)
      item = create(:categorizable_item, categorizable: person)
      event = TimelineServices::RecordEvent.call(subject: item, action: "destroyed")
      expected_label = event.snapshot["label"]

      item.destroy!
      event.reload
      expect(event.subject).to be_nil

      renderer = described_class.new(event, owner: person)
      output = renderer.label

      expect(output).to include(CGI.escapeHTML(expected_label))
      expect(output).to include("from #{person.timeline_label}")
      expect(output).not_to include("href")
    end

    it "renders the bare label when the owner is gone" do
      person = create(:person)
      item = create(:categorizable_item, categorizable: person)
      event = TimelineServices::RecordEvent.call(subject: item, action: "destroyed")

      item.destroy!
      person.destroy!
      event.reload

      renderer = described_class.new(event, owner: nil)
      output = renderer.label

      expect(output).to include(CGI.escapeHTML(event.snapshot["label"]))
      expect(output).not_to include("href")
    end
  end
end
