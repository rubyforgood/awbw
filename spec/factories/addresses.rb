FactoryBot.define do
  factory :address do
    association :addressable, factory: :project
    
    street_address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }

    country { Faker::Address.country}
    locality { Address::LOCALITIES.sample }
    county { Faker::Address.community }
    la_city_council_district { Faker::Number.between(from: 1, to: 15) }
    la_supervisorial_district { Faker::Number.between(from: 1, to: 5) }
    la_service_planning_area { Faker::Number.between(from: 1, to: 8) }
  end
end
