FactoryBot.define do
  factory :staff_tag do
    sequence(:name) { |n| "Staff Tag #{n}" }
    description { "What this tag means." }

    trait :archived do
      archived_at { Time.current }
    end
  end

  factory :staff_tagging do
    association :staff_tag
    association :staff_taggable, factory: :person
  end
end
