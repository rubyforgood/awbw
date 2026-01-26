FactoryBot.define do
  factory :downloadable_asset, class: "DownloadableAsset" do
    association :owner, factory: :resource
    after(:build) do |asset|
      asset.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.pdf")),
        filename: "sample.pdf",
        content_type: "application/pdf"
      )
    end

    trait :with_image do
      after(:build) do |asset|
    asset.file.attach(
    io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
    filename: "sample.png",
    content_type: "image/png"
  )
  end
    end
  end
end
