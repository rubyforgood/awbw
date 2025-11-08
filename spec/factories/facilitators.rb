FactoryBot.define do
  factory :facilitator do
    association :user
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :with_organization do
      after(:create) do |facilitator|
        facilitator.organizations << create(:organization)
      end
    end
  end
end
