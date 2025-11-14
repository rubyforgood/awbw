FactoryBot.define do
  factory :event_registration do
    association :registrant, factory: :user
    association :event
  end
end
