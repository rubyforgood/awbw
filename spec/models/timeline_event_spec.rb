# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimelineEvent do
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
  end
end
