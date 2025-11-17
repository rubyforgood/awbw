FactoryBot.define do
  factory :facilitator do
    association :user
    association :created_by, factory: :user
    association :updated_by, factory: :user
    first_name { Faker::Name.first_name.gsub("'", " ") }
    last_name { Faker::Name.last_name.gsub("'", " ") }

    trait :with_organization do
      after(:create) do |facilitator|
        facilitator.organizations << create(:organization)
      end
    end
  end
end
