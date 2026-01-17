FactoryBot.define do
  factory :sector do
    sequence(:name) { |n| "Sector Name #{n}" }
    published { false }

    trait :published do
      published { true }
    end

    trait :other do
      # name { 'Other' }
      sequence(:name) { |n| "Other #{n}" }
    end
  end
end
