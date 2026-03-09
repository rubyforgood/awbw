FactoryBot.define do
  factory :workshop_variation do
    association :workshop
    association :windows_type
    sequence(:name) { |n| "Variation #{n}" }
    rhino_body { "<p>Variation details using CKEditor</p>" }
    author_credit_preference { "full_name" }
    sequence(:position) { |n| n }
    published { false }

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
