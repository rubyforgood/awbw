class PersonRecap
  AFFILIATION_LIMIT = 8
  TRAINING_LIMIT = 8

  attr_reader :person

  def initialize(person)
    @person = person.decorate
  end

  def affiliations
    @affiliations ||= person.affiliations
      .active_or_pending
      .where.not(organization_id: nil)
      .includes(:organization)
      .order(start_date: :desc)
      .limit(AFFILIATION_LIMIT)
      .to_a
  end

  def trainings
    @trainings ||= person.event_registrations
      .joins(:event)
      .where(events: { facilitator_training: true })
      .includes(:event)
      .order("events.start_date DESC")
      .limit(TRAINING_LIMIT)
      .to_a
  end

  def membership
    return @membership if defined?(@membership)

    @membership = if Membership.enabled?
      person.memberships.active.order(end_date: :desc).first ||
        person.memberships.upcoming.order(:start_date).first ||
        person.memberships.ended.order(end_date: :desc).first
    end
  end

  def affiliated_since
    person.affiliated_since_date
  end

  def empty?
    affiliations.empty? && trainings.empty? && membership.nil?
  end
end
