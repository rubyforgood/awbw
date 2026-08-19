module Analytics
  # A person's affiliation history as one time-ordered list: every affiliation
  # they hold, the facilitator trainings they registered for (which can confer
  # facilitator status), and their membership periods — merged newest-first.
  #
  # Everything is read from its own table, so this is the complete picture. Unlike
  # AffiliationTimeline it carries no Ahoy edit history — that stays on each
  # affiliation's own edit page, where a single record's audit trail belongs.
  class PersonAffiliationTimeline
    Entry = Data.define(:kind, :occurred_at, :record) do
      def affiliation? = kind == :affiliation
      def training? = kind == :training
      def membership? = kind == :membership
    end

    def initialize(person)
      @person = person
    end

    def entries
      @entries ||= (affiliation_entries + training_entries + membership_entries)
        .sort_by { |entry| entry.occurred_at || Time.at(0) }
        .reverse
    end

    def any? = entries.any?
    def affiliations? = affiliation_entries.any?
    def trainings? = training_entries.any?
    def memberships? = membership_entries.any?

    # The organizations this person is affiliated with, so a training's linked
    # organizations can be flagged as conferring status somewhere they belong.
    def affiliated_organization_ids
      @affiliated_organization_ids ||= affiliations.filter_map(&:organization_id).to_set
    end

    private

    def affiliations
      @affiliations ||= @person.affiliations.includes(organization: { logo_attachment: :blob }).to_a
    end

    # Timestamps arrive as a mix of Date and Time, which can't be sorted against
    # each other.
    def entry(kind:, occurred_at:, record:)
      Entry.new(kind:, occurred_at: occurred_at&.to_time, record:)
    end

    def affiliation_entries
      @affiliation_entries ||= affiliations.map do |affiliation|
        entry(kind: :affiliation, occurred_at: affiliation.start_date || affiliation.created_at,
              record: affiliation)
      end
    end

    # Dated by the event itself rather than by when the row was written, so it
    # sits alongside the affiliation dates it explains.
    def training_entries
      @training_entries ||= @person.event_registrations
        .joins(:event).where(events: { facilitator_training: true })
        .includes(:event, :organizations)
        .map { |registration| entry(kind: :training, occurred_at: registration_date(registration), record: registration) }
    end

    def membership_entries
      return @membership_entries if defined?(@membership_entries)
      return @membership_entries = [] unless Membership.enabled?

      @membership_entries = MembershipInvoice.joins(:membership)
        .where(memberships: { person_id: @person.id })
        .includes(:membership)
        .map { |invoice| entry(kind: :membership, occurred_at: invoice.start_date, record: invoice) }
    end

    def registration_date(registration)
      registration.event&.start_date || registration.created_at
    end
  end
end
