FactoryBot.define do
  factory :faq do
    question { Faker::Lorem.question }
    answer { Faker::Lorem.paragraph }
    published { false }
    sequence(:position) { |n| n }

    trait :featured do
      featured { true }
    end

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end

    trait :publicly_visible do
      publicly_visible { true }
    end

    trait :publicly_featured do
      publicly_featured { true }
    end
  end
end
