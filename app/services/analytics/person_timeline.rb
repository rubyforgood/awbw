module Analytics
  # Merges a person's Ahoy events and communications into one timestamp-ordered
  # timeline. They live in separate tables, so the merge happens in Ruby — fine
  # for a bounded, admin-only person history.
  class PersonTimeline
    Entry = Data.define(:kind, :record, :occurred_at) do
      def communication? = kind == :communication
    end

    def initialize(events:, communications:)
      @events = events
      @communications = communications
    end

    def entries
      @entries ||= (event_entries + communication_entries).sort_by(&:occurred_at).reverse
    end

    private

    def event_entries
      @events.map { |event| Entry.new(kind: :event, record: event, occurred_at: event.time) }
    end

    def communication_entries
      @communications.map { |notification| Entry.new(kind: :communication, record: notification, occurred_at: notification.created_at) }
    end
  end
end
