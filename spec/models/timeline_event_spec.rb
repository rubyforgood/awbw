# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimelineEvent do
  describe "action_label" do
    it "renders destroyed as removed" do
      event = described_class.new(action: "destroyed", snapshot: { "changes" => {} })
      expect(event.action_label).to eq("removed")
    end

    it "humanizes other actions" do
      event = described_class.new(action: "created", snapshot: { "changes" => {} })
      expect(event.action_label).to eq("created")
    end
  end

  describe "subject validation" do
    it "accepts a Timelineable subject" do
      person = build(:person)
      event = described_class.new(subject: person, action: "created", snapshot: { "changes" => {} })
      expect(event).to be_valid
    end

    it "rejects a non-Timelineable subject" do
      workshop = build(:workshop)
      event = described_class.new(subject: workshop, action: "created", snapshot: { "changes" => {} })
      expect(event).not_to be_valid
      expect(event.errors[:subject]).to include("must include Timelineable")
    end

    it "accepts a subject marked for destruction (nested _destroy during an autosave)" do
      person = create(:person)
      item = create(:categorizable_item, categorizable: person)
      item.mark_for_destruction

      event = described_class.new(subject: item, action: "destroyed", snapshot: { "changes" => {} })

      expect(event).to be_valid
    end
  end
end
