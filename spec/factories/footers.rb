FactoryBot.define do
  factory :footer do
    phone { Faker::PhoneNumber.phone_number }
    general_questions { Faker::Lorem.sentence }
  end
end 