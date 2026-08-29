# frozen_string_literal: true

FactoryBot.define do
  factory :contact_method do
    association :contactable, factory: :person

    kind { "phone" }
    value { Faker::PhoneNumber.phone_number }
  end
end
