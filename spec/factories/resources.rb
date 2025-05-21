FactoryBot.define do
  factory :resource do
    # Associations
    association :user
    association :workshop
    association :windows_type

    title { Faker::Lorem.sentence }
    kind { ['Resource', 'LeaderSpotlight', 'SectorImpact', 'Story', 'Theme', 'Scholarship', 'TemplateAndHandout', 'ToolkitAndForm'].sample }
    text { Faker::Lorem.paragraphs.join("\n\n") }
    featured { false }
    inactive { false }

    # Needs setup for nested attributes (categories, sectors, images, attachments, form) if required for tests
  end
end 