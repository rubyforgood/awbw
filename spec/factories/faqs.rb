FactoryBot.define do
  factory :faq do
    question { Faker::Lorem.question }
    answer { Faker::Lorem.paragraph }
    published { true }
    sequence(:position) { |n| n }
  end
end
