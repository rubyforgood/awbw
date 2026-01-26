FactoryBot.define do
  factory :workshop_variation do
    association :workshop
    sequence(:name) { |n| "Variation #{n}" }
    code { "<p>Variation details using CKEditor</p>" }
    sequence(:position) { |n| n }
    inactive { false }
  end
end
