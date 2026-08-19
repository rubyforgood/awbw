module Analytics
  # One affiliation's story in time order: the edits made to the affiliation
  # itself, the registration that minted it, the facilitator trainings the person
  # registered for, and their membership periods — merged newest-first.
  #
  # Only the edits come from Ahoy. Ahoy records *changes*, and only those made
  # while a `Current.user`/`Current.source` was set, so imported and seeded rows
  # have no events at all. Everything else is read from its own table, which is
  # the complete answer; Ahoy is used for the affiliation's own columns because
  # nothing else records them.
  class AffiliationTimeline
    Entry = Data.define(:kind, :occurred_at, :record, :linked_here, :minted) do
      def change? = kind == :change
      def training? = kind == :training
      def membership? = kind == :membership
      def provenance? = kind == :provenance
    end

    def initialize(affiliation, limit: ResourceHistory::DEFAULT_LIMIT)
      @affiliation = affiliation
      @limit = limit
    end

    def entries
      @entries ||= (change_entries + provenance_entries + training_entries + membership_entries)
        .sort_by { |entry| entry.occurred_at || Time.at(0) }
        .reverse
    end

    def any? = entries.any?
    def trainings? = training_entries.any?
    def memberships? = membership_entries.any?

    private

    def person
      @affiliation.person
    end

    def minting_registration
      @affiliation.event_registration
    end

    # The timestamps arrive as a mix of Time and Date, which can't be sorted
    # against each other.
    def entry(kind:, occurred_at:, record:, linked_here: false, minted: false)
      Entry.new(kind:, occurred_at: occurred_at&.to_time, record:, linked_here:, minted:)
    end

    def change_entries
      @change_entries ||= ResourceHistory.new(@affiliation, limit: @limit).entries.map do |change|
        entry(kind: :change, occurred_at: change.time, record: change, linked_here: true)
      end
    end

    # The minting registration usually IS one of the trainings below, and gets
    # marked there rather than duplicated. This covers the other case: a job
    # affiliation minted by a registration to an event that isn't a training.
    def provenance_entries
      return [] unless minting_registration
      return [] if training_entries.any? { |candidate| candidate.record.id == minting_registration.id }

      [ entry(kind: :provenance, occurred_at: registration_date(minting_registration),
              record: minting_registration, minted: true) ]
    end

    # Dated by the event itself rather than by when the row was written, so it
    # sits alongside the affiliation dates it explains.
    def training_entries
      return @training_entries if defined?(@training_entries)
      return @training_entries = [] unless person

      registrations = person.event_registrations
        .joins(:event).where(events: { facilitator_training: true })
        .includes(:event, :organizations)

      @training_entries = registrations.map do |registration|
        entry(kind: :training, occurred_at: registration_date(registration), record: registration,
              linked_here: registration.organizations.any? { |org| org.id == @affiliation.organization_id },
              minted: registration.id == @affiliation.event_registration_id)
      end
    end

    def membership_entries
      return @membership_entries if defined?(@membership_entries)
      return @membership_entries = [] unless person && Membership.enabled?

      invoices = MembershipInvoice.joins(:membership)
        .where(memberships: { person_id: person.id })
        .includes(:membership)

      @membership_entries = invoices.map do |invoice|
        entry(kind: :membership, occurred_at: invoice.start_date, record: invoice)
      end
    end

    def registration_date(registration)
      registration.event&.start_date || registration.created_at
    end
  end
end
