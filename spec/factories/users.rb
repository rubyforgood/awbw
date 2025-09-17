# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { "password" }
    password_confirmation { "password" }

    trait :super_user do # admin user
      super_user { true }
    end
  end
end
