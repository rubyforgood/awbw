FactoryBot.define do
  factory :event do
    association :created_by, factory: :user
    title { "sample title" }
    description { "sample description" }
    # Default to the ambient zone so factory-built times (`Time.zone.local(...)`)
    # display in the same zone they were constructed in. Production events default
    # to Pacific via the DB column; override explicitly to exercise zone behavior.
    time_zone { Time.zone.name }
    start_date { 12.days.from_now }
    end_date   { 14.days.from_now }
    registration_close_date { 13.days.from_now }
    cost_cents { 1099 }
    publicly_visible { false }

    trait :featured do
      featured { true }
    end

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end

    trait :publicly_visible do
      publicly_visible { true }
    end

    trait :publicly_featured do
      publicly_featured { true }
    end

    trait :ended do
      start_date { 14.days.ago }
      end_date { 12.days.ago }
      registration_close_date { 13.days.ago }
    end

    trait :registration_closed do
      registration_close_date { 13.days.ago }
    end

    trait :with_primary_asset do
      after(:build) do |event|
        event.primary_asset = build(:primary_asset, :with_file, owner: event)
      end
    end

    trait :with_gallery_assets do
      after(:build) do |event|
        event.gallery_assets << build(:gallery_asset, :with_file, owner: event)
        event.gallery_assets << build(:gallery_asset, :with_file, owner: event)
      end
    end
  end
end
