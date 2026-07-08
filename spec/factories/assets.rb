FactoryBot.define do
  factory :asset do
    association :owner, factory: :user

    # Default to no type -- must use a trait

    # --- Traits for type-specific subclasses ---
    factory :primary_asset, class: "PrimaryAsset"
    factory :gallery_asset, class: "GalleryAsset"
    factory :rich_text_asset, class: "RichTextAsset"

    trait :with_file do
      after(:build) do |image|
        image.file.attach(
          io: File.open(Rails.root.join("app", "assets", "images", "missing.png")),
          filename: "missing.png",
          content_type: "image/png"
        )
      end
    end

    trait :with_pdf do
      after(:build) do |asset|
        asset.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/sample.pdf")),
          filename: "sample.pdf",
          content_type: "application/pdf"
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
