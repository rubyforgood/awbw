FactoryBot.define do
  factory :tutorial do
    title { "MyString" }
    body { "MyText" }
    featured { false }
    published { false }
    position { 1 }
    youtube_url { "MyString" }

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
