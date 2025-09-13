FactoryBot.define do
  factory :address do
    association :organization
    
    street { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip { Faker::Address.zip_code }

    country { Faker::Address.country}
    locality { ["LA City", "LA County", "Southern CA", "Northern CA", "Central CA", "Orange County", "Outside CA", "Outside USA"].sample }
    county { Faker::Address.state }
    la_city_council_district { Faker::Number.between(from: 1, to: 15) }
    la_supervisorial_district { Faker::Number.between(from: 1, to: 5) }
    la_service_planning_area { Faker::Number.between(from: 1, to: 8) }
  end
end
