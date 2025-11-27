FactoryBot.define do
  factory :category_type do
    sequence(:name) { |n| "Category Type Name #{n}" }
    published { true }
  end
end
