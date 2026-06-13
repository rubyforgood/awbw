FactoryBot.define do
  factory :external_processor_payment do
    association :person

    amount_cents { 1000 }
    amount_cents_remaining { 1000 }
    currency { "usd" }
    pay_charge { nil }
    skip_pay_charge_validation { true }

    trait :with_pay_charge do
      pay_charge
      skip_pay_charge_validation { false }
    end
  end
end
