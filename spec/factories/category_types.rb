FactoryBot.define do
  factory :category_type do
    sequence(:name) { |n| "Category Type Name #{n}" }
    published { true }

    trait :age_range do
      sequence(:name) { |n| "AgeRange #{n}" }
    end

    factory :age_range, parent: :category_type do
      sequence(:name) { |n| "AgeRange #{n}" }
    end
  end
end
