FactoryBot.define do
  factory :workshop_variation do
    association :workshop
    sequence(:name) { |n| "Variation #{n}" }
    code { "<p>Variation details using CKEditor</p>" }
    sequence(:position) { |n| n }
    published { false }

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end
  end
end
