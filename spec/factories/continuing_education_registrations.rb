FactoryBot.define do
  factory :continuing_education_registration do
    association :event_registration
    hours { 6 }
    professional_license { association(:professional_license, person: event_registration.registrant) }
  end
end
