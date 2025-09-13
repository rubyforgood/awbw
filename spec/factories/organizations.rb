FactoryBot.define do
  factory :organization do
    name { Faker::Company.name }
    start_date { Faker::Date.between(from: 2.years.ago, to: 1.year.ago) }
    close_date { nil }
    website_url { Faker::Internet.url }
    agency_type { ["Non-Profit", "Government", "For-Profit", "Other"].sample }
    agency_type_other { nil }
    phone { Faker::PhoneNumber.phone_number }
    mission { Faker::Company.catch_phrase }
    project_id { Faker::Number.number(digits: 4).to_s }

    trait :with_facilitator do
      after(:create) do |organization|
        organization.facilitators << create(:facilitator)
      end
    end

    trait :with_workshop do
      after(:create) do |organization|
        organization.workshops << create(:workshop)
      end
    end
  end
end
