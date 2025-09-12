FactoryBot.define do
  factory :event_registration do
    first_name { "John" }
    last_name { "Doe" }
    email { "john.doe@example.com" }
    association :event
  end
end
