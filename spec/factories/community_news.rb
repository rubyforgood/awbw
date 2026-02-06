FactoryBot.define do
  factory :community_news do
    title { "MyString" }
    published { false }
    featured { false }
    reference_url { "" }
    youtube_url { "" }
    association :author, factory: :user
    association :created_by, factory: :user
    association :updated_by, factory: :user

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end

    trait :featured do
      featured { true }
    end

    trait :with_project do
      association :project
    end

    trait :with_windows_type do
      association :windows_type
    end
  end
end
