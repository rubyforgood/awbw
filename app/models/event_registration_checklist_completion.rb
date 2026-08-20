class EventRegistrationChecklistCompletion < ApplicationRecord
  belongs_to :event_registration
  belongs_to :completed_by, class_name: "User", optional: true

  validates :step,
    presence: true,
    inclusion: { in: ->(_) { EventRegistration::CHECKLIST_STEPS.keys } },
    uniqueness: { scope: :event_registration_id }
end
