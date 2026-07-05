FactoryBot.define do
  factory :other_response do
    person
    kind { "sector" }
    sequence(:text) { |n| "Equine therapy #{n}" }
    status { "pending" }

    trait :kept do
      status { "kept" }
    end

    trait :dismissed do
      status { "dismissed" }
    end

    trait :promoted do
      status { "promoted" }
      association :promotable, factory: :sector
    end
  end
end
