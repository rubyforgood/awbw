FactoryBot.define do
  factory :faq do
    question { Faker::Lorem.question }
    answer { Faker::Lorem.paragraph }
    published { false }
    sequence(:position) { |n| n }

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end
  end
end
