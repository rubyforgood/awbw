FactoryBot.define do
  factory :tutorial do
    title { "MyString" }
    body { "MyText" }
    featured { false }
    published { false }
    position { 1 }
    youtube_url { "MyString" }
  end
end
