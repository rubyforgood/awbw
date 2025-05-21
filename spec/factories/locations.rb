FactoryBot.define do
  factory :location do
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    country { Faker::Address.country }
  end
end 