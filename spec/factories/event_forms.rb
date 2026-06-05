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
  end
end
