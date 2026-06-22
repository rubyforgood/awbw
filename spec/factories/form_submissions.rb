FactoryBot.define do
  factory :form_submission do
    association :person
    association :form

    # Submissions are event-less by default; opt in when the test needs one.
    trait :with_event do
      association :event
    end
  end
end
