require "rails_helper"

RSpec.describe PendingReviewSummary do
  describe "#queues" do
    it "counts the unpromoted ideas in each review queue" do
      create(:story_idea)
      create(:story_idea, :with_story)
      create(:workshop_variation_idea)
      create(:workshop_idea)

      summary = described_class.new
      counts = summary.queues.to_h { |queue| [ queue.model, queue.count ] }

      expect(counts).to eq(
        StoryIdea => 1,
        WorkshopVariationIdea => 1,
        WorkshopIdea => 1
      )
    end
  end

  describe "#pending_queues" do
    it "only returns queues with at least one pending item" do
      create(:story_idea)

      summary = described_class.new

      expect(summary.pending_queues.map(&:model)).to eq([ StoryIdea ])
    end
  end

  describe "#total_count and #any?" do
    it "sums the pending items across all queues" do
      create(:story_idea)
      create(:workshop_idea)

      summary = described_class.new

      expect(summary.total_count).to eq(2)
      expect(summary.any?).to be(true)
    end

    it "reports nothing pending when every idea is promoted" do
      create(:story_idea, :with_story)

      summary = described_class.new

      expect(summary.total_count).to eq(0)
      expect(summary.any?).to be(false)
    end
  end
end
