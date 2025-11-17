FactoryBot.define do
  factory :quote do
    quote { Faker::Lorem.sentence }
    speaker_name { Faker::Name.name.gsub("'", " ") }
    age { rand(18..99) }
    gender { ['M', 'F', 'O', nil].sample }
    inactive { false }
    workshop_id { nil }
  end
end 