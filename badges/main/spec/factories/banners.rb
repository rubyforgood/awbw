FactoryBot.define do
  factory :banner do
    content { "MyText" }
    show { true }
    association :created_by, factory: :user
    association :updated_by, factory: :user
  end
end
