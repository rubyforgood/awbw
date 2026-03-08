FactoryBot.define do
  factory :video_recording do
    title { "MyString" }
    body { "MyText" }
    featured { false }
    published { false }
    position { 1 }
    youtube_url { "MyString" }
    is_instructional { true }
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
      is_instructional { true }
      is_podcast { false }
    end

    trait :podcast do
      is_instructional { false }
      is_podcast { true }
    end

    trait :both do
      is_instructional { true }
      is_podcast { true }
    end
  end

  # Backwards compatibility
  factory :tutorial, class: 'VideoRecording', parent: :video_recording do
    is_instructional { true }
    is_podcast { false }
  end
end
