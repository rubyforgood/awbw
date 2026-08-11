require "rails_helper"

RSpec.describe AssetUrlImporter do
  let(:owner) { create(:story_idea) }
  let(:png_path) { Rails.root.join("app", "assets", "images", "missing.png") }

  # Stub the network: URI#open returns a local IO that quacks like an open-uri
  # response (responds to #content_type), so no real HTTP request is made.
  def stub_download(content_type: "image/png", io: File.open(png_path))
    io.define_singleton_method(:content_type) { content_type }
    allow_any_instance_of(URI::HTTP).to receive(:open).and_return(io)
  end

  it "downloads the URL and attaches it to a new asset on the owner" do
    stub_download
    asset = described_class.new(
      url: "https://stories.awbw.org/wp-content/uploads/pic.png",
      owner: owner,
      type: "PrimaryAsset",
      title: "Cover"
    ).call

    expect(asset).to be_persisted
    expect(asset).to be_a(PrimaryAsset)
    expect(asset.owner).to eq(owner)
    expect(asset.title).to eq("Cover")
    expect(asset.file).to be_attached
    expect(asset.file.filename.to_s).to eq("pic.png")
    expect(owner.assets.reload).to include(asset)
  end

  it "defaults to a GalleryAsset" do
    stub_download
    asset = described_class.new(url: "https://example.com/a.png", owner: owner).call
    expect(asset).to be_a(GalleryAsset)
  end

  it "raises a wrapped Error for a non-http url" do
    expect {
      described_class.new(url: "ftp://example.com/a.png", owner: owner).call
    }.to raise_error(described_class::Error, /not an http/)
  end

  it "raises a wrapped Error when the download fails" do
    allow_any_instance_of(URI::HTTP).to receive(:open)
      .and_raise(OpenURI::HTTPError.new("404 Not Found", nil))
    expect {
      described_class.new(url: "https://example.com/missing.png", owner: owner).call
    }.to raise_error(described_class::Error, /could not download/)
  end
end
