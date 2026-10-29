FactoryBot.define do
  factory :membership do
    association :person
    start_date { Date.current }
    end_date { start_date + Membership::INVOICE_PERIOD - 1.day }

    trait :autorenewal_cancelled do
      autorenewal_cancelled_at { Time.current }
    end
  end
end
