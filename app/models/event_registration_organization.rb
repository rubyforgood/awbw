class EventRegistrationOrganization < ApplicationRecord
  belongs_to :event_registration
  belongs_to :organization

  validates :organization_id, uniqueness: { scope: :event_registration_id }

  # Labels of the org values written from this registration's form answers
  # ("website", "type", "ZIP on the Austin work address"). Recorded when the org
  # is linked so the linking page can persistently say what the submission
  # changed on an org that already existed — the flash notice saying so is gone
  # by the next page load.
  def form_filled_labels
    Array(form_filled_fields)
  end

  def record_form_fills(labels)
    merged = (form_filled_labels + labels).uniq
    return if merged == form_filled_labels

    update!(form_filled_fields: merged)
  end
end
