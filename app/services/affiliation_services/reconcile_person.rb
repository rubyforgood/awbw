module AffiliationServices
  # The single classifier for one person's facilitator affiliations with one
  # organization, in the context of one event. `ReconcileEvent` iterates it across
  # an event's registrants; it also stands alone for a single person.
  #
  # A person is a facilitator of an org iff they have at least one `attended`
  # registration to that org from a facilitator training — across ALL their
  # training registrations, so no-showing one but attending another keeps them
  # active.
  #
  # `include_unowned: false` (the default) touches only rows the registration flow
  # minted, leaving hand-created ones alone; the bulk page passes true.
  class ReconcilePerson
    Decision = Struct.new(:affiliation, :action, :reason, keyword_init: true) do
      def actionable?
        action != :noop
      end
    end

    ACTIVE_ATTENDED = "Active — attended".freeze
    TRAINING_PENDING = "Training hasn't ended yet".freeze
    ALREADY_DEACTIVATED = "Already deactivated — didn't attend".freeze
    ALREADY_ENDED = "Already ended — not by reconciliation".freeze
    LAPSED = "Ended — a return is recorded as a new affiliation".freeze
    # Topic on the comment reconciliation leaves behind, so a row can say why it
    # ended without a dedicated column (ADR-0003 D6b).
    COMMENT_TOPIC = "Reconciliation".freeze
    NOT_ATTENDED = "Didn't attend — no affiliation created".freeze
    # `registered` after the event is a gap in the record, not an outcome:
    # #attendance_recorded? deliberately excludes it. Acting on it would be acting
    # on missing data, so the row is surfaced for an admin to resolve instead.
    ATTENDANCE_NOT_RECORDED = "Attendance never recorded — set an outcome first".freeze

    def self.call(person:, organization:, event:, registration: nil, include_unowned: false)
      new(person:, organization:, event:, registration:, include_unowned:).call
    end

    def initialize(person:, organization:, event:, registration: nil, include_unowned: false)
      @person = person
      @organization = organization
      @event = event
      @registration = registration
      @include_unowned = include_unowned
    end

    # One Decision per affiliation in scope, plus a create/no-create decision when
    # the person has none. No writes.
    def plan
      @plan ||= @event.facilitator_training? ? training_plan : non_training_plan
    end

    # Returns whether anything changed, so callers can count real changes.
    def perform(action, affiliation: nil)
      return false if affiliation.nil? && action != :create

      case action
      when :create then create_and_note
      when :delete then affiliation.destroy!
      when :deactivate then deactivate(affiliation)
      else return false
      end
      true
    end

    def call
      plan.select(&:actionable?).filter_map do |decision|
        decision.action if perform(decision.action, affiliation: decision.affiliation)
      end
    end

    private

    def completed_training?
      return @completed_training if defined?(@completed_training)

      @completed_training = @person.event_registrations.attended
        .joins(:event).where(events: { facilitator_training: true })
        .joins(:event_registration_organizations)
        .where(event_registration_organizations: { organization_id: @organization.id })
        .exists?
    end

    def deactivate(affiliation)
      ends_on = deactivation_end_date(affiliation)
      affiliation.update!(end_date: ends_on, inactive: true)
      note(affiliation, "Ended #{ends_on.strftime('%b %-d, %Y')} and marked inactive by reconciliation " \
                        "for #{@event.title} — no attended facilitator training for #{@organization.name} on record.")
    end

    def create_and_note
      created = @person.affiliations.facilitators.where(organization: @organization).pluck(:id)
      create_affiliation
      fresh = @person.affiliations.facilitators.where(organization: @organization).where.not(id: created)
      fresh.each { |affiliation| note(affiliation, "Created by reconciliation for #{@event.title}.") }
    end

    # Why a row changed, on the affiliation's own comments rather than a dedicated
    # column — the edit page and its history already surface them (ADR-0003 D6b).
    def note(affiliation, body)
      affiliation.comments.create!(topic: COMMENT_TOPIC, body: body,
                                   created_by: Current.user, updated_by: Current.user)
    end

    def ended_by_reconciliation?(affiliation)
      affiliation.comments.any? { |comment| comment.topic == COMMENT_TOPIC }
    end

    # The event is over and nobody said what happened. Distinct from cancelled or
    # transferred out, which are decisions; this is an unfilled roster.
    #
    # Looked up rather than taken from `@registration`, which callers that only ask
    # for a plan don't have to pass — the status has to be read either way.
    def attendance_unrecorded?
      @event.ended? && registration_here&.status == "registered"
    end

    # One per (registrant, event) — the DB enforces it with a unique index.
    def registration_here
      return @registration_here if defined?(@registration_here)

      @registration_here = @registration || @person.event_registrations.find_by(event_id: @event.id)
    end

    def minted_here?(affiliation)
      affiliation.event_registration&.event_id == @event.id
    end

    # Only rows this training did NOT mint reach here (minted ones are deleted), and
    # they record facilitation that really happened — so they end at this training
    # and the years before it survive, leaving anchored program status where it was
    # (ADR-0003 D6). Never before the row's own start date.
    def deactivation_end_date(affiliation)
      [ @event.start_date&.to_date || Date.current, affiliation.start_date ].compact.max
    end

    # A non-training event confers no facilitation, so it only removes what was
    # auto-created off it.
    def non_training_plan
      facilitator_affiliations.filter_map do |affiliation|
        next unless minted_here?(affiliation)

        Decision.new(affiliation:, action: :delete)
      end
    end

    def training_plan
      decisions = reconcilable_affiliations.map { |affiliation| classify(affiliation) }
      decisions << creation_decision if needs_affiliation?
      decisions
    end

    # Someone with no active facilitator affiliation needs one when they have never
    # had one, or when they completed a training here and are returning after a
    # lapse — the return is a NEW row, never a resurrected one (ADR-0003 D6a).
    def needs_affiliation?
      return false unless @registration
      return false if facilitator_affiliations.any?(&:active?)

      facilitator_affiliations.empty? || completed_training?
    end

    def classify(affiliation)
      if completed_training?
        return Decision.new(affiliation:, action: :noop, reason: ACTIVE_ATTENDED) if affiliation.active?

        Decision.new(affiliation:, action: :noop, reason: LAPSED)
      elsif !affiliation.active?
        reason = ended_by_reconciliation?(affiliation) ? ALREADY_DEACTIVATED : ALREADY_ENDED
        Decision.new(affiliation:, action: :noop, reason:)
      elsif attendance_unrecorded?
        Decision.new(affiliation:, action: :noop, reason: ATTENDANCE_NOT_RECORDED)
      elsif deactivation_ready?(affiliation)
        # The row this training minted recorded an assumption that never came true,
        # so it goes rather than lingering as a zero-length row. Anything older
        # records facilitation that really happened and is only ended (ADR-0003 D6).
        Decision.new(affiliation:, action: minted_here?(affiliation) ? :delete : :deactivate)
      else
        Decision.new(affiliation:, action: :noop, reason: TRAINING_PENDING)
      end
    end

    # Waits for the governing training to end, so a pre-event run never deactivates.
    # A hand-entered row has no source training, so it waits on this event.
    def deactivation_ready?(affiliation)
      affiliation.event_registration_id ? affiliation.event_registration&.event&.ended? : @event.ended?
    end

    def creation_decision
      return Decision.new(action: :create) if !@event.ended? || completed_training?

      Decision.new(action: :noop, reason: NOT_ATTENDED)
    end

    def create_affiliation
      CreateFromRegistration.call(
        person: @person, organization: @organization, facilitator_training: true,
        training_date: @event.start_date, event_registration: @registration
      )
    end

    def reconcilable_affiliations
      return facilitator_affiliations if @include_unowned

      facilitator_affiliations.select(&:event_registration_id)
    end

    def facilitator_affiliations
      @facilitator_affiliations ||= @person.affiliations.facilitators
        .where(organization: @organization)
        .includes(:comments, event_registration: :event)
        .to_a
    end
  end
end
