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

    transient do
      categories { [] }
      sectors { [] }
    end

    after(:create) do |workshop, evaluator|
      evaluator.categories.each do |category|
        workshop.categories << category unless workshop.categories.include?(category)
      end

      evaluator.sectors.each do |sector|
        workshop.sectors << sector unless workshop.sectors.include?(sector)
      end
    end

    trait :with_organization do
      after(:create) do |workshop|
        workshop.organizations << create(:organization)
      end
    end

    trait :published do
      inactive { false }
    end
  end
end
