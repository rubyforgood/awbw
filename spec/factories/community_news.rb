FactoryBot.define do
  factory :community_news do
    title { "MyString" }
    body { "MyText" }
    youtube_url { "MyString" }
    published { false }
    featured { false }
    inactive { false }
    author { "MyString" }
    reference_url { "MyString" }
    project { nil }
    windows_type { nil }
    workshop { nil }
    created_by { nil }
    updated_by { nil }
  end
end
