FactoryBot.define do
  factory :payment do
    # Polymorphic associations
    association :payer, factory: :user
    association :payable, factory: :event

    # Required attributes
    amount_cents { 1000 } # $10.00
    currency { "usd" }
    status { "succeeded" }
    stripe_payment_intent_id { "pi_#{SecureRandom.hex(24)}" }

    # Optional attributes
    stripe_charge_id { nil }
    failure_code { nil }
    failure_message { nil }
    stripe_metadata { nil }

    trait :pending do
      status { "pending" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :succeeded do
      status { "succeeded" }
    end

    trait :failed do
      status { "failed" }
      failure_code { "card_declined" }
      failure_message { "Your card was declined." }
    end

    trait :canceled do
      status { "canceled" }
    end

    trait :refunded do
      status { "refunded" }
    end

    trait :partially_refunded do
      status { "partially_refunded" }
    end

    trait :with_charge_id do
      stripe_charge_id { "ch_#{SecureRandom.hex(24)}" }
    end
  end
end
