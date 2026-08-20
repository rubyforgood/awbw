module PeopleHelper
  # Targets a new comment can be attached to from the aggregated person-comments
  # page: the person's own profile, their login account, and each of their
  # registrations, scholarships, and CE registrations. Each entry carries a
  # signed GlobalID the composer submits so the controller can resolve (and
  # trust) the commentable without threading a route per target.
  def person_comment_targets(person)
    records = [ person.object ]
    records << person.user if person.user
    records.concat(person.event_registrations.includes(:event).order("events.start_date DESC").references(:events))
    records.concat(person.scholarships.includes(allocation: :allocatable).order(created_at: :desc))
    records.concat(
      ContinuingEducationRegistration.where(event_registration_id: person.event_registrations.ids)
        .includes(event_registration: :event)
    )
    records.concat(person.topic_subscriptions.includes(:topic_subscription_type).newest_first)

    records.map { |record| { label: commentable_label(record), sgid: record.to_sgid.to_s } }
  end
end
