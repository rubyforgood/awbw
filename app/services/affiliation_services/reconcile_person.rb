module AffiliationServices
  # Decides what should happen to one person's facilitator affiliations with one
  # organization, in the context of one event. This is the single classifier —
  # `ReconcileEvent` iterates it across an event's registrants, and it can be
  # called on its own for a single person (e.g. after an attendance change).
  #
  # A person is a facilitator of an org iff they have at least one `attended`
  # registration to that org from a facilitator-training event. The decision spans
  # ALL their training registrations for the org, so no-showing one training but
  # attending another keeps them active.
  #
  # Actions:
  #   :create      — facilitator training, none exists yet but one should (pre-event
  #                  for anyone, post-event only for attendees).
  #   :deactivate  — facilitator training, its (ended) training wasn't completed.
  #                  Same-days the row: `end_date := start_date` plus an explicit
  #                  `inactive: true`, since the model's date rule alone still reads
  #                  a row ending today or later as active. Preserves `start_date`
  #                  and is reversible.
  #   :reactivate  — facilitator training, same-dayed earlier, now attended.
  #   :delete      — NOT a facilitator training: an affiliation auto-created off
  #                  this event that shouldn't exist.
  #   :noop        — nothing to do; the decision carries a `reason`.
  #
  # `include_unowned:` is the auto-vs-manual gate. False (the default) touches only
  # rows the registration flow minted (`event_registration_id` present), leaving
  # hand-created / historical rows alone. The bulk page passes true — an admin
  # reviewing every row is expected to reconcile hand-entered ones too.
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

    # One Decision per facilitator affiliation in scope, plus a create/no-create
    # decision when the person has none. No writes.
    def plan
      @plan ||= @event.facilitator_training? ? training_plan : non_training_plan
    end

    # Perform one planned action. Returns whether anything changed, so callers can
    # count real changes rather than attempted ones.
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

    # Apply every actionable decision. Returns the actions taken.
    def call
      plan.select(&:actionable?).filter_map do |decision|
        decision.action if perform(decision.action, affiliation: decision.affiliation)
      end
    end

    private

    # Whether the person has any `attended` registration to this org from a
    # facilitator-training event — i.e. actually became a facilitator there.
    def completed_training?
      return @completed_training if defined?(@completed_training)

      @completed_training = @person.event_registrations.attended
        .joins(:event).where(events: { facilitator_training: true })
        .joins(:event_registration_organizations)
        .where(event_registration_organizations: { organization_id: @organization.id })
        .exists?
    end

    # A non-training event confers no facilitation, so it only removes facilitator
    # affiliations that were auto-created off this event. Rows minted elsewhere —
    # and hand-entered ones, which carry no link — are none of its business.
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

    # Deactivation waits for the governing training to end, so a pre-event run never
    # deactivates. A hand-entered row has no source training, so it waits on this event.
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
