FactoryBot.define do
  factory :category do
    # Needs a unique name
    sequence(:name) { |n| "Category Name #{n}" }
    published { true }

    # Association: belongs_to :metadatum
    association :category_type
  end
end
