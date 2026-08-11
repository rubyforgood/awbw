class EventRegistrationOrganization < ApplicationRecord
  belongs_to :event_registration
  belongs_to :organization
  # The submission whose answers describe this org, pinned when the link is made.
  # Optional: an org an admin linked by hand matches no submission, and links
  # predate the column. Nullified rather than blocking if the submission is deleted.
  belongs_to :form_submission, optional: true

  validates :organization_id, uniqueness: { scope: :event_registration_id }

  # Short descriptions of what this registration's form answers wrote onto the org
  # — "website", "type", "street and ZIP on the Austin work address" — not the
  # submitted answers themselves, which stay on the form submission. Entries vary
  # from a single word to a phrase, hence descriptions rather than labels ("label"
  # already means a form question's display text elsewhere in this codebase).
  # Recorded when the org is linked so the linking page can persistently say what
  # the submission changed on an org that already existed — the flash notice saying
  # so is gone by the next page load. Reads through the column so a link the form
  # never autofilled answers with [] rather than nil.
  def form_autofill_descriptions
    Array(super)
  end

  def record_autofill(descriptions)
    merged = (form_autofill_descriptions + descriptions).uniq
    return if merged == form_autofill_descriptions

    update!(form_autofill_descriptions: merged)
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
