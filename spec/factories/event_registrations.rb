FactoryBot.define do
  factory :event_registration do
    association :registrant, factory: :person
    association :event
  end
end
