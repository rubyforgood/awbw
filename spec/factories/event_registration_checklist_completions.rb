FactoryBot.define do
  factory :event_registration_checklist_completion do
    association :event_registration
    step { EventRegistration::CHECKLIST_STEPS.keys.first }
    completed_at { Time.current }
    association :completed_by, factory: :user
  end
end
