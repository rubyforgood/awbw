FactoryBot.define do
  factory :story do
    association :windows_type
    association :project
    association :workshop
    title { Faker::Lorem.sentence }
    rhino_body { "<p>My Body</p>" }
    association :created_by, factory: :user
    association :updated_by, factory: :user

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
