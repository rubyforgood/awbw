# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { "password" }
    password_confirmation { "password" }

    trait :with_perms do
      after(:create) do |user|
        # Create all permission types and associate them with the user
        [:adult, :children, :combined].each do |perm_trait|
          permission = create(:permission, perm_trait)
          user.permissions << permission
        end
      end
    end
  end
end
