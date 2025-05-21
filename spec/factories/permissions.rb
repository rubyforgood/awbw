FactoryBot.define do
  factory :permission do
    # Assuming 'security_cat' is the main attribute we need to set
    security_cat { "Default Permission Category" } # Provide a sensible default

    # Add other necessary attributes for a valid Permission object based on its model definition
    # name { "Default Permission Name" }
    # description { "Default Description" }

    trait :adult do
      security_cat { "Adult Windows" }
    end

    trait :children do
      security_cat { "Children's Windows" }
    end

    trait :combined do
      security_cat { "Combined Adult and Children's Windows" }
    end
  end
end 