FactoryBot.define do
  factory :asset do
    association :owner, factory: :user

    # Default to no type -- must use a trait

    # --- Traits for type-specific subclasses ---
    factory :primary_asset, class: "PrimaryAsset"
    factory :gallery_assets, class: "GalleryAsset"

    trait :with_file do
      after(:build) do |image|
        image.file.attach(
          io: File.open(Rails.root.join("app", "assets", "images", "missing.png")),
          filename: "missing.png",
          content_type: "image/png"
        )
      end
    end

    trait :invalid_format do
      after(:build) do |image|
        image.file.attach(
          io: File.open(Rails.root.join("app", "assets", "images", "invalid.webp")),
          filename: "invalid.webp",
          content_type: "image/webp"
        )
      end
    end
  end
end
