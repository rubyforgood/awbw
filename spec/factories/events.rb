FactoryBot.define do
  factory :event do
    association :created_by, factory: :user
    title { "sample title" }
    description { "sample description" }
    start_date { 12.days.from_now }
    end_date   { 14.days.from_now }
    registration_close_date { 13.days.from_now }
    inactive { false }
    cost_cents { 1099 }
    publicly_visible { false }

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
