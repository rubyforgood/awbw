FactoryBot.define do
  factory :form do
    association :owner, factory: :user

    # Add other attributes if needed based on schema
    # name { "Default Form Name" } # Name seems to be method-generated
  end
end 