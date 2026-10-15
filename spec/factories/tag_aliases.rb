FactoryBot.define do
  factory :tag_alias do
    sequence(:name) { |n| "Legacy Term #{n}" }
    source { "filemaker" }
    association :aliasable, factory: :sector
  end
end
