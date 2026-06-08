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

    trait :bulk_payment do
      role { "bulk_payment" }
    end

    trait :ce_credit do
      role { "ce_credit" }
    end
  end
end
