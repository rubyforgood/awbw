FactoryBot.define do
  factory :address do
    association :organization
    
    street { "123 Main Street" }
    city { "Los Angeles" }
    state { "CA" }
    zip { "90210" }
    
    country { "United States" }
    locality { "LA City" }
    county { "Los Angeles" }
    la_city_council_district { 1 }
    la_supervisorial_district { 1 }
    la_service_planning_area { 1 }
  end
end
