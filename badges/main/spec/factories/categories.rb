FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category Name #{n}" }
    published { false }
    # position is managed by positioned gem
    association :category_type #  belongs_to :metadatum

    trait :published do
      published { true }
    end

    trait :category_age_range do
      association :category_type, factory: :age_range
    end
  end
end
