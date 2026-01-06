FactoryBot.define do
  factory :event do
    title { "sample title" }
    description { "sample description" }
    start_date { 12.day.from_now }
    end_date { 14.days.from_now }
    registration_close_date { 13.days.from_now }
    publicly_visible { true }
    cost_cents { 1099 }

    trait :registration_closed do
      after(:build) do |event|
        event.registration_close_date = 13.days.ago
      end
    end

    trait :primary_asset_with_file do
      after(:build) do |event|
        event.primary_asset = build(:image, :with_file, owner: event)
      end
    end

    trait :gallery_assets_with_file do
      after(:build) do |event|
        event.gallery_assets << build(:image, :with_file, owner: event)
      end
    end
  end
end
