# frozen_string_literal: true

# Summarizes the admin review queues for the dashboard: user-submitted ideas
# that have not yet been promoted into their published counterparts. Each queue
# exposes its label, pending count, and originating model so the view can link
# to the relevant index.
class PendingReviewSummary
  Queue = Data.define(:label, :count, :model)

  QUEUE_DEFINITIONS = [
    { model: StoryIdea, label: "Story ideas" },
    { model: WorkshopVariationIdea, label: "Workshop variation ideas" },
    { model: WorkshopIdea, label: "Workshop ideas" }
  ].freeze

  def queues
    @queues ||= QUEUE_DEFINITIONS.map do |definition|
      Queue.new(
        label: definition[:label],
        count: definition[:model].pending_review.count,
        model: definition[:model]
      )
    end
  end

  def pending_queues
    queues.select { |queue| queue.count.positive? }
  end

  def total_count
    queues.sum(&:count)
  end

  def any?
    total_count.positive?
  end
end
