require "rails_helper"

RSpec.describe ImageHelper, type: :helper do
  describe "#portrait_image?" do
    def image_blob(content_type: "image/png", **metadata)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("image"), filename: "image.png", content_type: content_type, metadata: metadata
      )
    end

    it "is true for an image taller than it is wide" do
      expect(helper.portrait_image?(image_blob(width: 600, height: 900))).to be true
    end

    it "is false for a landscape or square image" do
      expect(helper.portrait_image?(image_blob(width: 900, height: 600))).to be false
      expect(helper.portrait_image?(image_blob(width: 600, height: 600))).to be false
    end

    it "is false when the image hasn't been analyzed yet" do
      expect(helper.portrait_image?(image_blob)).to be false
    end

    it "is false for a portrait PDF" do
      expect(helper.portrait_image?(image_blob(content_type: "application/pdf", width: 612, height: 792))).to be false
    end

    it "reads through an attachment to its blob" do
      asset = create(:primary_asset)
      asset.file.attach(image_blob(width: 600, height: 900))

      expect(helper.portrait_image?(asset.file)).to be true
    end

    it "is false for a fallback asset path" do
      expect(helper.portrait_image?("theme_default.png")).to be false
    end
  end
end
