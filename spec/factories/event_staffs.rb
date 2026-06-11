FactoryBot.define do
  factory :event_staff do
    association :event
    association :person
    title { "Lead facilitator" }
  end
end
