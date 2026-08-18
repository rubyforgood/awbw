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
    NOT_ATTENDED = "Didn't attend — no affiliation created".freeze

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
      when :create then create_affiliation
      when :delete then affiliation.destroy!
      when :deactivate then affiliation.update!(end_date: affiliation.start_date || Date.current, inactive: true)
      when :reactivate then affiliation.update!(end_date: nil, inactive: false)
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

    # A non-training event confers no facilitation, so it only removes what was
    # auto-created off it.
    def non_training_plan
      facilitator_affiliations.filter_map do |affiliation|
        next unless affiliation.event_registration&.event_id == @event.id

        Decision.new(affiliation:, action: :delete)
      end
    end

    def training_plan
      decisions = reconcilable_affiliations.map { |affiliation| classify(affiliation) }
      decisions << creation_decision if facilitator_affiliations.empty? && @registration
      decisions
    end

    def classify(affiliation)
      if completed_training?
        return Decision.new(affiliation:, action: :noop, reason: ACTIVE_ATTENDED) if affiliation.active?

        Decision.new(affiliation:, action: :reactivate)
      elsif !affiliation.active?
        Decision.new(affiliation:, action: :noop, reason: ALREADY_DEACTIVATED)
      elsif deactivation_ready?(affiliation)
        Decision.new(affiliation:, action: :deactivate)
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
        .includes(event_registration: :event)
        .to_a
    end
  end
end
