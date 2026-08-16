module Analytics
  # Interleaves a person's Ahoy activity events and their communications
  # (Notification records) into one timestamp-ordered timeline so the admin
  # person-scoped activities page can show them together instead of in separate
  # panels. Notifications aren't ahoy-tracked, so the two streams are merged in
  # Ruby; person history is bounded and this is an admin-only view.
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
