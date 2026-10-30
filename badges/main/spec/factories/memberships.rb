FactoryBot.define do
  factory :membership do
    association :person, factory: :person_without_user
    start_date { Date.current }
    end_date { start_date + Membership::INVOICE_PERIOD - 1.day }

    trait :renewal_off do
      renewal_off_at { Time.current }
    end
  end
end
