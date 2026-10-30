FactoryBot.define do
  factory :continuing_education_registration do
    association :event_registration
    hours { 6 }
    cost_cents { 15_000 }
    professional_license { association(:professional_license, person: event_registration.registrant) }

    trait :approved do
      approved_at { Time.current }
    end
  end
end
