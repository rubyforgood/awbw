FactoryBot.define do
  factory :resource do
    association :user
    title { Faker::Lorem.sentence }
    kind { Resource::PUBLISHED_KINDS.sample }

    # Use after(:create) to assign sectors
    after(:create) do |resource|
      sector = Sector.published.first || create(:sector) # adjust factory as needed
      resource.sectors << sector
    end

    trait :featured do
      featured { true }
    end

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end

    trait :publicly_visible do
      publicly_visible { true }
    end

    trait :publicly_featured do
      publicly_featured { true }
    end
  end
end
