FactoryBot.define do
  factory :community_news do
    title { "MyString" }
    published { false }
    featured { false }
    rhino_body { "<p>Test content</p>" }
    # reference_url { nil }
    # youtube_url { nil }
    association :author, factory: :user
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

    trait :with_organization do
      association :organization
    end

    trait :with_windows_type do
      association :windows_type
    end
  end
end
