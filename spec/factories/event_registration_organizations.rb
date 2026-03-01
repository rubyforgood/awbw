FactoryBot.define do
  factory :event_registration_organization do
    association :event_registration
    association :organization
  end
end
