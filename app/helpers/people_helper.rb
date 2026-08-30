module PeopleHelper
  # Records a new comment or communication can be filed against from a person's
  # aggregated pages: their own profile, their login account, and each of their
  # registrations, scholarships, CE registrations, and subscriptions. Each entry
  # carries a signed GlobalID the composer submits, so the controller can resolve
  # (and trust) the target without threading a route per record.
  def person_record_targets(person)
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
