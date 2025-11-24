FactoryBot.define do
  factory :workshop do
    # Associations
    association :user
    association :windows_type

    title { Faker::Lorem.sentence }

    inactive { false }
    featured { false }
    objective { Faker::Lorem.paragraph }
    materials { Faker::Lorem.paragraph }
    time_opening { rand(0..75) }

    trait :with_organization do
      after(:create) do |workshop|
        workshop.organizations << create(:organization)
      end
    end
  end
end