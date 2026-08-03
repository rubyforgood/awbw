FactoryBot.define do
  factory :dues_registration do
    association :dues_membership
    start_date { Date.current }
    end_date { start_date + 1.year - 1.day }
    cost_cents { 2_500 }

    trait :comped do
      cost_cents { 0 }
    end
  end
end
