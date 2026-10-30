FactoryBot.define do
  factory :payment do
    association :person, factory: :person_without_user

    amount_cents { 1000 }
    amount_cents_remaining { 1000 }
    currency { "usd" }
    type { "CashPayment" }
  end
end
