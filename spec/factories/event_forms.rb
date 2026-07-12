FactoryBot.define do
  factory :event_form do
    association :event
    association :form
    role { "registration" }

    trait :registration do
      role { "registration" }
    end

    trait :scholarship do
      role { "scholarship" }
    end

    trait :continuing_education do
      role { "continuing_education" }
    end
  end
end
