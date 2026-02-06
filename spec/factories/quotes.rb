FactoryBot.define do
  factory :quote do
    quote { Faker::Lorem.sentence }
    speaker_name { Faker::Name.name.gsub("'", " ") }
    age { rand(18..99) }
    gender { [ 'M', 'F', 'O', nil ].sample }
    published { false }
    workshop_id { nil }

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end
  end
end
