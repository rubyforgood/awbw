# frozen_string_literal: true

FactoryBot.define do
  factory :user_permission do
    association :user
    association :permission
  end
end
