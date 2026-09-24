module PeopleHelper
  # Records a new comment or communication can be filed against from a person's
  # aggregated pages: their own profile, their login account, and each of their
  # registrations, scholarships, CE registrations, subscriptions, form
  # submissions, affiliations, staff tags, and the reports, workshop
  # ideas/logs/variations/variation ideas, stories, and story ideas they're
  # credited on. Kept in step with the sources PersonCommentAggregator gathers, so
  # anything filed here also shows in the feed. Each entry carries a signed
  # GlobalID the composer submits, so the controller can resolve (and trust) the
  # target without threading a route per record.
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
    records.concat(person.form_submissions.includes(:form, :event).order(created_at: :desc))
    records.concat(person.affiliations.includes(:organization).order(created_at: :desc))
    records.concat(person.staff_taggings.includes(:staff_tag))
    records.concat(PersonCreditedRecords.monthly_reports(person).order(created_at: :desc))
    records.concat(PersonCreditedRecords.workshop_ideas(person).order(created_at: :desc))
    records.concat(PersonCreditedRecords.workshop_logs(person).order(created_at: :desc))
    records.concat(PersonCreditedRecords.workshop_variations(person).order(created_at: :desc))
    records.concat(PersonCreditedRecords.workshop_variation_ideas(person).order(created_at: :desc))
    records.concat(PersonCreditedRecords.stories(person).order(created_at: :desc))
    records.concat(PersonCreditedRecords.story_ideas(person).order(created_at: :desc))

    records.map { |record| { label: commentable_label(record), sgid: record.to_sgid.to_s } }
  end
end
