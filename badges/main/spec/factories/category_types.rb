FactoryBot.define do
  factory :category_type do
    sequence(:name) { |n| "Category Type Name #{n}" }
    published { true }

    trait :age_range do
      name { "AgeRange" }
    end

    factory :age_range, parent: :category_type do
      name { "AgeRange" }
    end
  end
end
