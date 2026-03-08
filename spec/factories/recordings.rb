FactoryBot.define do
  factory :recording do
    title { "MyString" }
    body { "MyText" }
    featured { false }
    published { false }
    position { 1 }
    youtube_url { "MyString" }
    is_tutorial { true }
    is_podcast { false }

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

    trait :tutorial do
      is_tutorial { true }
      is_podcast { false }
    end

    trait :podcast do
      is_tutorial { false }
      is_podcast { true }
    end

    trait :both do
      is_tutorial { true }
      is_podcast { true }
    end
  end

  # Backwards compatibility
  factory :tutorial, class: 'Recording', parent: :recording do
    is_tutorial { true }
    is_podcast { false }
  end
end
