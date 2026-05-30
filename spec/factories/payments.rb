FactoryBot.define do
  factory :payment do
    association :person

    amount_cents { 1000 }
    amount_cents_remaining { 1000 }
    currency { "usd" }
    type { "CashPayment" }
  end
end
