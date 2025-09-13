FactoryBot.define do
  factory :facilitator do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    primary_email_address { Faker::Internet.unique.email }
    primary_email_address_type { 'Personal' }
    street_address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state }
    zip { Faker::Address.postcode }
    country { Faker::Address.country}
    mailing_address_type { 'Personal' }
    phone_number { Faker::PhoneNumber.phone_number }
    phone_number_type { 'Personal' }
  end
end
