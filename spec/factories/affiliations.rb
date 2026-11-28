FactoryBot.define do
  factory :affiliation do
    association :organization
    association :person
    type { Affiliation::TYPE_JOB }

    trait :facilitator do
      type { Affiliation::TYPE_FACILITATOR }
    end
  end
end
