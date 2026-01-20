FactoryBot.define do
  factory :community_news do
    title { "MyString" }
    published { true }
    featured { false }
    # reference_url { nil }
    # youtube_url { nil }
    association :author, factory: :user
    association :created_by, factory: :user
    association :updated_by, factory: :user

    trait :published do
      published { true }
    end

    trait :featured do
      featured { true }
    end

    trait :with_organization do
      association :organization
    end

    trait :with_windows_type do
      association :windows_type
    end
  end
end
