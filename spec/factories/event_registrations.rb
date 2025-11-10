FactoryBot.define do
  factory :event_registration do
    association :user
    association :event
  end
end
