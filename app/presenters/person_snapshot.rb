class PersonSnapshot
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

  # FA rows first, each with its org's JAs folded underneath as notes; then a row per JA at JA-only orgs.
  Row = Struct.new(:affiliation, :job_affiliations)

  def affiliation_rows
    @affiliation_rows ||= begin
      facilitators, jobs = affiliations.partition(&:facilitator?)
      facilitator_orgs = facilitators.map(&:organization_id).to_set
      folded, job_only = jobs.partition { |job| facilitator_orgs.include?(job.organization_id) }

      facilitators.map { |fa| Row.new(fa, folded.select { |job| job.organization_id == fa.organization_id }) } +
        job_only.map { |job| Row.new(job, []) }
    end
  end

  def trainings
    @trainings ||= person.event_registrations
      .joins(:event)
      .where(events: { facilitator_training: true })
      .includes(:event, :organizations)
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

  # Logins that can sign in lead, matching PersonDecorator#suggested_user_account.
  def user_accounts
    @user_accounts ||= person.user_accounts.sort_by.with_index { |user, index| [ user.has_access? ? 0 : 1, index ] }.map(&:decorate)
  end

  def affiliated_since
    person.affiliated_since_date
  end

  def affiliations_heading
    return "Affiliations" if affiliated_since.blank?

    "Affiliated since #{affiliated_since.strftime("%b %Y")}"
  end
end
