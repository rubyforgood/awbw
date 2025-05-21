FactoryBot.define do
  factory :workshop do
    # Associations
    association :user
    association :windows_type

    title { Faker::Lorem.sentence }

    inactive { false }
    featured { false }
    objective { Faker::Lorem.paragraph }
    materials { Faker::Lorem.paragraph }
    time_hours { rand(0..2) }
    time_minutes { [0, 15, 30, 45].sample }

    thumbnail_file_name { nil }
    header_file_name { nil }

  end
end