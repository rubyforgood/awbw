FactoryBot.define do
  factory :bookmark_annotation do
    association :bookmark

    annotation { { note: "This is an annotation." }.to_json }
  end
end 