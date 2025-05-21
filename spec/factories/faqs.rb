FactoryBot.define do
  factory :faq do
    question { Faker::Lorem.question }
    answer { Faker::Lorem.paragraph }
    inactive { false }
    sequence(:ordering) { |n| n }
  end
end 