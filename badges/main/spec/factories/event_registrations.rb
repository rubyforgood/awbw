FactoryBot.define do
  factory :event_registration do
    association :registrant, factory: :person
    association :event

    trait :scholarship do
      scholarship_recipient { true }
      scholarship_tasks_completed { true }
    end
  end
end
