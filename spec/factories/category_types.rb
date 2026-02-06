FactoryBot.define do
  factory :category_type do
    sequence(:name) { |n| "Category Type Name #{n}" }
    published { false }

    trait :age_range do
      # name { "AgeRange" }
      sequence(:name) { |n| "AgeRange #{n}" }
    end

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end

    factory :age_range, parent: :category_type do
      # name { "AgeRange" }
      sequence(:name) { |n| "AgeRange #{n}" }
    end
  end
end
