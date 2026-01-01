FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category Name #{n}" }
    published { false }
    association :category_type #  belongs_to :metadatum

    trait :published do
      published { true }
    end

    trait :category_age_range do
      association :category_type, factory: :age_range
    end
  end
end
