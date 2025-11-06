FactoryBot.define do
  factory :workshop_idea do
    title { "MyString" }
    description { "MyText" }
    staff_notes { "MyText" }
    association :windows_type
    tips { "MyText" }
    objective { "MyText" }
    materials { "MyText" }
    introduction { "MyText" }
    creation { "MyText" }
    closing { "MyText" }
    visualization { "MyText" }
    warm_up { "MyText" }
    opening_circle { "MyText" }
    demonstration { "MyText" }
    setup { "MyText" }
    instructions { "MyText" }
    optional_materials { "MyText" }
    notes { "MyText" }

    association :created_by, factory: :user
    association :updated_by, factory: :user
  end
end
