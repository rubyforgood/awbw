module AffiliationServices
  # Follows a facilitator-training registration's attendance (ADR-0003 D6e):
  #
  # - Marked attended, it creates the facilitator affiliation with every organization
  #   linked to the registration, starting on the training date (an on-demand
  #   training's: the day they're marked attended). An org linked later gets its row
  #   from the linking itself (CreateFromRegistration). A row reconciliation ended
  #   for this training is left for the reconcile page to reopen.
  # - Attendance taken back, it removes the open row attendance created here — but
  #   only while it still carries the date attendance gave it. A start date staff
  #   have set by hand since keeps the row, for reconciliation to judge.
  #
  # A row a registration created before facilitation waited for attendance is older
  # data: an on-demand one waits on the training's end date, and is moved to the
  # attended day rather than duplicated.
  class FollowAttendance
    # Comment topic marking a row dated by attendance, so taking it back can tell that
    # date from one staff entered.
    COMMENT_TOPIC = "Attendance".freeze

    def self.call(registration:) = new(registration:).call

    def self.note_start(affiliation)
      affiliation.comments.create_as_system!(
        topic: COMMENT_TOPIC,
        body: "Starts #{format_date(affiliation.start_date)}: marked attended at #{affiliation.event_registration.event.title}."
      )
    end

    def self.format_date(date) = date.strftime("%b %-d, %Y")

    def initialize(registration:)
      @registration = registration
      @event = registration.event
    end

    def call
      return unless @event&.facilitator_training?

      @registration.attended? ? start : take_back
    end

    private

    def start
      start_waiting_rows
      @registration.organizations.each do |organization|
        next if ended_here_by_reconciliation?(organization)

        CreateFromRegistration.call(
          person: @registration.registrant, organization: organization, training_date: @event.starts_on,
          organization_address: address_for(organization), repoint_address: false, event_registration: @registration
        )
      end
    end

    # A row reconciliation ended for this training (before they were marked attended)
    # is left for an admin to reopen or replace on the reconcile page — adding one
    # here would leave two rows for one unbroken engagement (ADR-0003 D6a).
    # Hand-entered rows count: reconciliation may have ended one of those too.
    def ended_here_by_reconciliation?(organization)
      ReconcilePerson.new(person: @registration.registrant, organization: organization, event: @event,
                          registration: @registration, include_unowned: true)
        .plan.any? { |decision| decision.action == :reactivate }
    end

    # Rows created at registration before attendance gated them.
    def start_waiting_rows
      return unless @event.on_demand_facilitator_training?

      starts_on = @registration.facilitator_start_on
      open_rows.each do |affiliation|
        next unless affiliation.start_date && starts_on && affiliation.start_date > starts_on

        self.class.note_start(affiliation) if affiliation.update(start_date: starts_on)
      end
    end

    def take_back
      open_rows.select { |affiliation| dated_by_attendance?(affiliation) }.each(&:destroy!)
    end

    # The address their current affiliation there already has (the one their
    # submission gave), else the organization's only one.
    def address_for(organization)
      current = @registration.registrant.affiliations.active_or_pending
        .where(organization: organization).where.not(organization_address_id: nil)
        .order(updated_at: :desc).first
      return current.organization_address if current

      addresses = organization.addresses.active
      addresses.first if addresses.count == 1
    end

    def open_rows
      Affiliation.facilitators
        .where(event_registration_id: @registration.id, end_date: nil, inactive: false)
        .includes(:comments).to_a
    end

    def dated_by_attendance?(affiliation)
      note = affiliation.comments.select { |comment| comment.topic == COMMENT_TOPIC }.max_by(&:id)
      return false unless note

      marked_on = note.created_at.in_time_zone(Event::PROGRAM_ZONE).to_date
      affiliation.start_date == (@event.facilitator_start_on(attended_on: marked_on) || marked_on)
    end
  end
end
