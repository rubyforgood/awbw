FactoryBot.define do
  factory :refund do
    association :refundable, factory: :payment
    association :recipient, factory: :person
    amount_cents { 500 }
    add_attribute(:method) { "check" }
  end
end
