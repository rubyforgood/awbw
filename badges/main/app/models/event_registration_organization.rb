class EventRegistrationOrganization < ApplicationRecord
  belongs_to :event_registration
  belongs_to :organization
  # The submission whose answers describe this org, pinned when the link is made.
  # Optional: an org an admin linked by hand matches no submission, and links
  # predate the column. Nullified rather than blocking if the submission is deleted.
  belongs_to :form_submission, optional: true

  validates :organization_id, uniqueness: { scope: :event_registration_id }

  # What this registration's form answers wrote onto the org, as
  # OrganizationServices::AutofillChange — the field, and the value that landed in
  # it. Not the submitted answers themselves, which stay on the form submission:
  # these are only the answers that actually changed the org. Recorded when the org
  # is linked so the linking page can persistently say what the submission did to an
  # org that already existed — the flash saying so is gone by the next page load.
  def form_autofill_changes
    OrganizationServices::AutofillChange.all_from_json(super)
  end

  # Merge in what a submission just wrote, newest value winning per field: a
  # registrant registering again with a corrected website should leave one entry
  # showing the value the org ended up with, not two that contradict each other.
  def record_autofill(changes)
    return if changes.blank?

    merged = form_autofill_changes.index_by(&:key).merge(changes.index_by(&:key)).values
    return if merged == form_autofill_changes

    update!(form_autofill_changes: merged.map(&:to_json_hash))
  end

  # Pin the submission this org's answers came from. Without it the linking page
  # re-derives the pairing on every request, and an org linked under a name the
  # registrant didn't type loses its discrepancy note as soon as a second org is
  # linked. Latest-wins, matching how a resubmission overwrites the org profile.
  def record_form_submission(submission)
    return if submission.nil? || form_submission_id == submission.id

    update!(form_submission: submission)
  end
end
