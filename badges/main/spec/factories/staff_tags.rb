FactoryBot.define do
  factory :staff_tag do
    sequence(:name) { |n| "Staff Tag #{n}" }
    description { "What this tag means." }

    trait :unpublished do
      published { false }
    end
  end

  factory :staff_tagging do
    association :staff_tag
    association :staff_taggable, factory: :person

    trait :marked do
      marked { true }
    end
  end
end
