FactoryBot.define do
  factory :workshop_variation do
    association :workshop
    sequence(:name) { |n| "Variation #{n}" }
    code { "<p>Variation details using CKEditor</p>" }
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
