FactoryBot.define do
  factory :scholarship do
    association :recipient, factory: :person
    amount_cents { 1000 }
    tasks_completed { false }
  end
end
