# frozen_string_literal: true

require "rails_helper"

RSpec.describe StoryAssetImportJob do
  let(:story) { create(:story) }

  it "imports the first URL as the primary asset and the rest as gallery assets" do
    calls = []
    allow(AssetUrlImporter).to receive(:new) do |url:, owner:, type:, title:|
      calls << { url: url, owner: owner, type: type, title: title }
      instance_double(AssetUrlImporter, call: nil)
    end

    described_class.perform_now(
      story,
      [ "https://ex.com/cover.jpg", "https://ex.com/two.jpg", "https://ex.com/three.jpg" ],
      title: "Alt text"
    )

    expect(calls).to eq([
      { url: "https://ex.com/cover.jpg", owner: story, type: "PrimaryAsset", title: "Alt text" },
      { url: "https://ex.com/two.jpg", owner: story, type: "GalleryAsset", title: "Alt text" },
      { url: "https://ex.com/three.jpg", owner: story, type: "GalleryAsset", title: "Alt text" }
    ])
  end

  it "skips blank URLs" do
    importer = instance_double(AssetUrlImporter, call: nil)
    expect(AssetUrlImporter).to receive(:new)
      .once.with(hash_including(url: "https://ex.com/only.jpg", type: "PrimaryAsset"))
      .and_return(importer)

    described_class.perform_now(story, [ "https://ex.com/only.jpg", "", nil ])
  end

  it "logs and continues when one image fails to download" do
    ok = instance_double(AssetUrlImporter, call: nil)
    bad = instance_double(AssetUrlImporter)
    allow(bad).to receive(:call).and_raise(AssetUrlImporter::Error, "404")
    allow(AssetUrlImporter).to receive(:new).and_return(bad, ok)

    expect(Rails.logger).to receive(:warn).with(/StoryAssetImportJob.*404/)

    expect {
      described_class.perform_now(story, [ "https://ex.com/bad.jpg", "https://ex.com/good.jpg" ])
    }.not_to raise_error
    expect(ok).to have_received(:call)
  end
end
