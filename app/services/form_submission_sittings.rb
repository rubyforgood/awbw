# Groups a person's form submissions for one event into sittings — the times they
# sat down to submit. Each registration is its own sitting, and the scholarship/CE
# forms saved in the same request join it; other forms submitted later cluster by
# time. Takes anything responding to role and created_at (records or Entry rows).
class FormSubmissionSittings
  WINDOW = 1.minute
  EVENT_FORM_JOIN = "INNER JOIN event_forms ON event_forms.form_id = form_submissions.form_id " \
                    "AND event_forms.event_id = form_submissions.event_id".freeze

  Entry = Data.define(:id, :form_name, :role, :created_at)

  # Sittings keyed by [person_id, event_id], over each event's own linked forms, in one query.
  # Roles come from the event's form link, so older submissions saved without a role still bundle.
  def self.for_events(event_ids, person_ids)
    FormSubmission.joins(EVENT_FORM_JOIN).joins(:form)
      .where(event_id: event_ids, person_id: person_ids).distinct
      .pluck(:person_id, :event_id, :id, Arel.sql("forms.name"), Arel.sql("event_forms.role"), :created_at)
      .group_by { |row| row.first(2) }
      .transform_values { |rows| new(rows.map { |_, _, id, form_name, role, created_at| Entry.new(id:, form_name:, role:, created_at:) }) }
  end

  def initialize(submissions)
    @submissions = submissions.sort_by(&:created_at)
  end

  def groups
    @groups ||= begin
      registrations, others = @submissions.partition { |submission| submission.role == "registration" }
      bundles = registrations.to_h { |registration| [ registration, [ registration ] ] }
      standalone = []
      others.each do |submission|
        nearest = registrations.min_by { |registration| gap(submission, registration) }
        if nearest && gap(submission, nearest) <= WINDOW
          bundles[nearest] << submission
        else
          standalone << submission
        end
      end
      clusters = standalone.slice_when { |earlier, later| later.created_at - earlier.created_at > WINDOW }.to_a
      (bundles.values + clusters).sort_by { |group| group.first.created_at }
    end
  end

  def count = groups.size

  def registered? = @submissions.any? { |submission| submission.role == "registration" }

  private

  def gap(submission, other) = (submission.created_at - other.created_at).abs
end
