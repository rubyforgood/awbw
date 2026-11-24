module AffiliationServices
  # Re-dates the facilitator affiliation an on-demand registration created when its
  # attendance changes (ADR-0003 D6e): marked attended, it starts that day; attendance
  # taken back, it returns to the training's end date.
  #
  # Only the open row this registration created moves. A start date staff have set by
  # hand since is kept when attendance is taken back.
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
      return unless @event&.on_demand_facilitator_training?

      @registration.attended? ? start_rows : return_rows
    end

    private

    def start_rows
      starts_on = @registration.facilitator_start_on
      open_rows.each do |affiliation|
        next unless affiliation.start_date && starts_on && affiliation.start_date > starts_on

        self.class.note_start(affiliation) if affiliation.update(start_date: starts_on)
      end
    end

    def return_rows
      starts_on = @registration.facilitator_start_on
      open_rows.select { |affiliation| dated_by_attendance?(affiliation) }.each do |affiliation|
        next unless affiliation.update(start_date: starts_on)

        affiliation.comments.create_as_system!(
          topic: COMMENT_TOPIC,
          body: "Start moved back to #{self.class.format_date(starts_on)}: no longer marked attended at #{@event.title}."
        )
      end
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
      affiliation.start_date == @event.facilitator_start_on(attended_on: marked_on)
    end
  end
end
