FactoryBot.define do
  factory :membership do
    association :person
    end_date { Date.current + 1.year }
    start_date { end_date ? end_date - 1.year : Date.current }

    trait :autorenewal_cancelled do
      autorenewal_cancelled_at { Time.current }
    end
  end
end
