FactoryBot.define do
  factory :organization_type do
    sequence(:name) { |n| "Organization Type #{n}" }
    published { false }

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end
  end
end
