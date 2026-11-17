# Groups a person's form submissions for one event into sittings — the times they
# sat down to submit. Each registration is its own sitting, and the scholarship/CE
# forms saved right after it in the same request join it; other forms submitted
# later cluster by time. Takes anything responding to role and created_at.
class FormSubmissionSittings
  WINDOW = 1.minute
  EVENT_FORM_JOIN = "INNER JOIN event_forms ON event_forms.form_id = form_submissions.form_id " \
                    "AND event_forms.event_id = form_submissions.event_id".freeze

  COUNTED_ROLES = (EventForm::ROLES - %w[bulk_payment]).freeze

  Entry = Data.define(:id, :form_name, :role, :created_at)

  # Sittings keyed by [person_id, event_id], over each event's own linked forms, in one query.
  # Roles come from the event's form link, so older submissions saved without a role still bundle.
  # Bulk payments are left out: they pay for other people, not the payer's own registration.
  def self.for_events(event_ids, person_ids)
    FormSubmission.joins(EVENT_FORM_JOIN).joins(:form)
      .where(event_id: event_ids, person_id: person_ids, event_forms: { role: COUNTED_ROLES }).distinct
      .pluck(:person_id, :event_id, :id, Arel.sql("forms.name"), Arel.sql("event_forms.role"), :created_at)
      .group_by { |row| row.first(2) }
      .transform_values { |rows| new(rows.map { |_, _, id, form_name, role, created_at| Entry.new(id:, form_name:, role:, created_at:) }) }
  end

  # Where a registration's registration-form answers live: its own event, or the original event for a
  # transferred-in registrant who didn't also register at the new one.
  Placement = Data.define(:sittings, :event_id, :original_event_title) do
    def from_original? = original_event_title.present?
  end

  # { registration id => Placement }, only for registrations with registration-form answers on file.
  def self.placements_for(registrations)
    originals = EventRegistration.joins(:event)
      .where(id: registrations.filter_map(&:transferred_from_registration_id))
      .pluck(:id, :event_id, Arel.sql("events.title"))
      .to_h { |id, event_id, title| [ id, [ event_id, title ] ] }
    event_ids = (registrations.map(&:event_id) + originals.values.map(&:first)).uniq
    by_key = for_events(event_ids, registrations.map(&:registrant_id).uniq)
    registrations.each_with_object({}) do |registration, placements|
      own = by_key[[ registration.registrant_id, registration.event_id ]]
      next placements[registration.id] = Placement.new(own, registration.event_id, nil) if own&.registered?

      original_event_id, title = originals[registration.transferred_from_registration_id]
      original = by_key[[ registration.registrant_id, original_event_id ]]
      placements[registration.id] = Placement.new(original, original_event_id, title) if original&.registered?
    end
  end

  # roles_by_form_id maps each form to its role on the event, so records saved without a role still group.
  def initialize(submissions, roles_by_form_id: {})
    @submissions = submissions.sort_by(&:created_at)
    @roles_by_form_id = roles_by_form_id
  end

  def role_of(submission) = @roles_by_form_id[submission.try(:form_id)] || submission.role

  def groups
    @groups ||= begin
      registrations, others = @submissions.partition { |submission| role_of(submission) == "registration" }
      bundles = registrations.to_h { |registration| [ registration, [ registration ] ] }
      standalone = []
      others.each do |submission|
        registration = registrations.reverse.find { |candidate| candidate.created_at <= submission.created_at }
        if registration && submission.created_at - registration.created_at <= WINDOW
          bundles[registration] << submission
        else
          standalone << submission
        end
      end
      clusters = standalone.slice_when { |earlier, later| later.created_at - earlier.created_at > WINDOW }.to_a
      (bundles.values + clusters).sort_by { |group| group.first.created_at }
    end
  end

  def count = groups.size

  def registered? = @submissions.any? { |submission| role_of(submission) == "registration" }
end
