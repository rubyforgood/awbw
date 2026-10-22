FactoryBot.define do
  factory :membership_invoice do
    association :membership
    start_date { Date.current }
    end_date { start_date + 1.year - 1.day }
    cost_cents { Membership.annual_cost_cents }

    trait :comped do
      cost_cents { 0 }
    end
  end
end
