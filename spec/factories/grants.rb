FactoryBot.define do
  factory :grant do
    name { "Healing Arts Scholarship Fund" }
    amount_cents { 500_000 }
    association :funder, factory: :organization
    funds_allocation_deadline { Date.current + 30 }
    funds_received_on { Date.current - 7 }
    eligibility_criteria { "Must be a current facilitator\nMust serve a partner organization" }
    tasks { "Submit application form\nComplete intake interview" }

    transient do
      categories { [] }
      sectors { [] }
    end

    after(:create) do |grant, evaluator|
      evaluator.sectors.each { |sector| grant.sectors << sector unless grant.sectors.include?(sector) }
      evaluator.categories.each { |category| grant.categories << category unless grant.categories.include?(category) }
    end

    trait :donated_by_person do
      association :funder, factory: :person
    end

    trait :planned_giving do
      planned_giving { true }
    end

    trait :in_memoriam do
      planned_giving { true }
      in_memoriam { true }
    end
  end
end
