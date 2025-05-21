FactoryBot.define do
  factory :image do
    association :owner, factory: :user

    association :report

    file_file_name { "test.jpg" }
    file_content_type { "image/jpeg" }
    file_file_size { 1024 }
    file_updated_at { Time.zone.now }

    trait :invalid_format do
      file_content_type { "image/webp" }
      file_file_name { "invalid.webp" }
    end
  end
end 