FactoryBot.define do
  factory :contact_method do
    association :contactable, factory: :person

    kind { "phone" }
    value { Faker::PhoneNumber.cell_phone }
  end
end
