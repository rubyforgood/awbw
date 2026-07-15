FactoryBot.define do
  factory :other_response do
    association :owner, factory: :person
    field_identifier { "additional_sectors" }
    sequence(:text) { |n| "Equine therapy #{n}" }
    status { "pending" }
    # kind is derived from field_identifier (sector fields → "sector").

    trait :organization_type do
      association :owner, factory: :organization
      field_identifier { "agency_type" }
    end

    trait :generic do
      field_identifier { "how_did_you_hear" }
    end

    trait :kept do
      status { "kept" }
    end

    trait :dismissed do
      status { "dismissed" }
    end

    trait :promoted do
      status { "promoted" }
      association :promotable, factory: :sector
    end
  end
end
