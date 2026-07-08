require "rails_helper"

RSpec.describe AssetDecorator do
  describe "#image? / #pdf?" do
    it "identifies an image" do
      decorated = described_class.decorate(create(:gallery_asset, :with_file))
      expect(decorated.image?).to be(true)
      expect(decorated.pdf?).to be(false)
    end

    it "identifies a PDF" do
      decorated = described_class.decorate(create(:gallery_asset, :with_pdf))
      expect(decorated.pdf?).to be(true)
      expect(decorated.image?).to be(false)
    end
  end

  describe "#thumbnail" do
    it "returns a representation for an image" do
      decorated = described_class.decorate(create(:gallery_asset, :with_file))
      expect(decorated.thumbnail).to be_present
    end

    it "is nil for a PDF (embedded as an iframe instead)" do
      decorated = described_class.decorate(create(:gallery_asset, :with_pdf))
      expect(decorated.thumbnail).to be_nil
    end

    it "is nil when no file is attached" do
      decorated = described_class.decorate(create(:gallery_asset))
      expect(decorated.thumbnail).to be_nil
    end
  end

  describe "#inline_url" do
    it "is a same-origin inline blob path" do
      decorated = described_class.decorate(create(:gallery_asset, :with_pdf))
      expect(decorated.inline_url).to include("/rails/active_storage/blobs")
    end
  end

  describe "labels" do
    let(:workshop) { create(:workshop) }

    subject(:decorated) { described_class.decorate(create(:gallery_asset, :with_pdf, title: "Handout", owner: workshop)) }

    it "exposes type, owner, filename and content-type labels" do
      expect(decorated.type_label).to eq("Gallery asset")
      expect(decorated.owner_type_label).to eq("Workshop")
      expect(decorated.filename).to eq("sample.pdf")
      expect(decorated.content_type_label).to eq("PDF")
    end
  end
end
