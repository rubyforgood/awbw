FactoryBot.define do
  factory :media_file do
    association :report

    file_file_name { "test_document.pdf" }
    file_content_type { "application/pdf" }
    file_file_size { 1024 }
    file_updated_at { Time.zone.now }
  end
end 