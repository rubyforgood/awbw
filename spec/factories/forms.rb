FactoryBot.define do
  factory :form do
    name { "Test Form" }

    trait :standalone do
      owner { nil }
    end

    trait :with_owner do
      association :owner, factory: :user
    end
  end
end
