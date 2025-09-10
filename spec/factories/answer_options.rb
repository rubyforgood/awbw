# frozen_string_literal: true

FactoryBot.define do
  factory :answer_option do
    name { "Option Text" }
    order { 1 }
  end
end
