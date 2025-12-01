FactoryBot.define do
  factory :category do
    # Needs a unique name
    sequence(:name) { |n| "Category Name #{n}" }
    published { false }

    # Association: belongs_to :metadatum
    association :category_type

    trait :published do
      published { true }
    end

    trait :category_age_range do
      association :category_type, factory: :age_range
    end
  end
end
