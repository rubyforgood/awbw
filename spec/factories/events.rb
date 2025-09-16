FactoryBot.define do
  factory :event do
    title { "sample title" }
    description { "sample description" }
    start_date { 1.day.from_now }
    end_date { 2.days.from_now }
    registration_close_date { 3.days.ago }
    publicly_visible { true }
  end
end
