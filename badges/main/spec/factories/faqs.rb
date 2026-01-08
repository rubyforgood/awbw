FactoryBot.define do
  factory :faq do
    question { Faker::Lorem.question }
    answer { Faker::Lorem.paragraph }
    inactive { false }
    sequence(:position) { |n| n }
  end
end
