FactoryBot.define do
  factory :allocation do
    association :source, factory: :payment
    association :allocatable, factory: :event_registration
    amount { 0 }
  end
end
