FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name.gsub("'", " ") }
    last_name  { Faker::Name.last_name.gsub("'", " ") }
    email      { Faker::Internet.unique.email(name: "#{first_name} #{last_name}") }
    password { "MyString" }
    # address { "MyString" }
    # address2 { "MyString" }
    # city { "MyString" }
    # city2 { "MyString" }
    # state { "MyString" }
    # state2 { "MyString" }
    # zip { "MyString" }
    # zip2 { "MyString" }
    # phone { "MyString" }
    # phone2 { "MyString" }
    # phone3 { "MyString" }
    # birthday { "2025-10-25" }
    # best_time_to_call { "MyString" }
    # comment { "MyText" }
    # notes { "MyText" }
    # confirmed { false }
    # inactive { false }
    # legacy { false }
    # legacy_id { 1 }
    # super_user { false }
    # agency_id { 1 }
    # facilitator_id { "" }
    # created_by_id { 1 }
    # updated_by_id { 1 }
    # reset_password_token { "MyString" }
    # reset_password_sent_at { "2025-10-25 22:57:35" }
    # remember_created_at { "2025-10-25 22:57:35" }
    # sign_in_count { 1 }
    # current_sign_in_at { "2025-10-25 22:57:35" }
    # current_sign_in_ip { "MyString" }
    # last_sign_in_at { "2025-10-25 22:57:35" }
    # last_sign_in_ip { "MyString" }
    # avatar_file_name { "MyString" }
    # avatar_content_type { "MyString" }
    # avatar_file_size { 1 }
    # avatar_updated_at { "2025-10-25 22:57:35" }
    # subscribecode { "MyString" }

    trait :admin do
      super_user { true }
    end

    trait :orphaned_reports do
      email { "orphaned_reports@awbw.org" }
      super_user { true }
    end
  end
end
