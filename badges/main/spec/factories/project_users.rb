FactoryBot.define do
  factory :project_user do
    association :project
    association :user

    position { :default }
  end
end 