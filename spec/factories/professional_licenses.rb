FactoryBot.define do
  factory :professional_license do
    association :person
    sequence(:number) { |n| "LIC-#{n}" }
    kind { "LMFT" }
    issuing_state { "CA" }

    trait :placeholder do
      number { nil }
    end
  end
end
