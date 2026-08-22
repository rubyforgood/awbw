FactoryBot.define do
  factory :quote do
    body { Faker::Lorem.sentence }
    speaker_name { Faker::Name.name.gsub("'", " ") }
    age { rand(18..99) }
    gender { [ 'M', 'F', 'O', nil ].sample }
    published { false }
    standout { false }
    workshop_id { nil }

    trait :featured do
      featured { true }
    end

    trait :standout do
      standout { true }
    end

    trait :with_author do
      association :author, factory: :person
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
