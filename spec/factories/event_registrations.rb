FactoryBot.define do
  factory :event_registration do
    first_name { "MyString" }
    last_name { "MyString" }
    email { "MyString" }
    event { nil }
  end
end
