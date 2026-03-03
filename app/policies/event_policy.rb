class EventPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?
    true
  end

  def show?
    return true if admin?

    if record.ended?
      authenticated? && record.published? && record.actively_registered?(user.person)
    else
      record.publicly_visible? || (authenticated? && record.published?)
    end
  end

  def register?
    authenticated? && record.published?
  end

  def edit?
    admin? || owner?
  end

  def update?
    admin? || owner?
  end

  def manage?
    admin? || owner?
  end

  alias_rule :preview?, to: :edit?

  private

  def owner?
    return false unless authenticated?
    return false unless record.is_a?(Event)
    record.created_by == user
  end

  relation_scope do |relation|
    next relation if admin?

    if authenticated?
      active_statuses = EventRegistration::ACTIVE_STATUSES.map { |s| relation.connection.quote(s) }.join(", ")
      relation
        .joins(
          "LEFT OUTER JOIN event_registrations
             ON event_registrations.event_id = events.id
             AND event_registrations.status IN (#{active_statuses})
           LEFT OUTER JOIN people
             ON people.id = event_registrations.registrant_id"
        )
        .published
        .where(
          "(events.end_date >= :now AND (events.registration_close_date IS NULL OR events.registration_close_date >= :now))
           OR people.id = :person_id",
          now: Time.current,
          person_id: user.person_id
        )
        .distinct
    else
      relation.publicly_visible
              .published
              .where("events.end_date >= ?", Time.current)
              .where("events.registration_close_date IS NULL OR events.registration_close_date >= ?", Time.current)
    end
  end
end
