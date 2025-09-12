FactoryBot.define do
  factory :category do
    # Needs a unique name
    sequence(:name) { |n| "Category Name #{n}" }
    published { true }

    # Association: belongs_to :metadatum
    association :metadatum
  end
end 