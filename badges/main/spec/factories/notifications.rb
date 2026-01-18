FactoryBot.define do
  factory :notification do
    association :noticeable, factory: :user
    kind { :reset_password_fyi }
    notification_type { 0 }
    recipient_role { :admin }
    recipient_email { Faker::Internet.email }
  end
end
