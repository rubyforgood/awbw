# frozen_string_literal: true

FactoryBot.define do
  factory :workshop_resource do
    association :workshop
    association :resource
  end
end
