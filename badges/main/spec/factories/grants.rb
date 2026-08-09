FactoryBot.define do
  factory :grant do
    name { "Healing Arts Scholarship Fund" }
    amount_cents { 500_000 }
    association :funder, factory: :organization
    funds_allocation_deadline { Date.current + 30 }
    funds_received_on { Date.current - 7 }
    eligibility_criteria { "Must be a current facilitator\nMust serve a partner organization" }
    tasks { "Submit application form\nComplete intake interview" }

    trait :donated_by_person do
      association :funder, factory: :person
    end
  end
end
