FactoryBot.define do
  factory :membership do
    association :person
    start_date { Date.current }
    end_date { start_date + Membership::INVOICE_PERIOD - 1.day }

    trait :renewal_off do
      renewal_off_at { Time.current }
    end
  end
end
