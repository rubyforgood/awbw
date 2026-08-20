require "rails_helper"

RSpec.describe Asset do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { should belong_to(:owner).optional } # Polymorphic
    it { should belong_to(:report).optional } # Assuming report can be optional
  end

  describe "validations" do
    # Paperclip matchers (might require paperclip-matchers gem and setup)
    # it { should have_attached_file(:file) }
    # it { should validate_attachment_content_type(:file)
    #              .allowing('image/jpeg', 'image/png', 'image/gif')
    #              .rejecting('text/plain', 'application/pdf') }
    # Presence validation for file itself is usually handled by Paperclip/ActiveStorage

    # TODO Move these to specific STI models as each will have different content types
    # it { should validate_content_type_of(:file).allowing(Media::ACCEPTED_CONTENT_TYPES) }
    # it { should validate_content_type_of(:file).rejecting("text/plain", "text/xml") }
  end

  describe "file size" do
    def asset_with_byte_size(bytes)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "sample.png", content_type: "image/png"
      )
      blob.update!(byte_size: bytes)
      Asset.new.tap { |asset| asset.file.attach(blob) }
    end

    it "rejects a file over the maximum" do
      asset = asset_with_byte_size(Asset::MAX_FILE_SIZE + 1)

      expect(asset).not_to be_valid
      expect(asset.errors[:file].join).to match(/too large/i)
    end

    it "accepts a file at the maximum" do
      expect(asset_with_byte_size(Asset::MAX_FILE_SIZE)).to be_valid
    end

    it "labels the maximum for display" do
      expect(Asset.max_file_size_label).to eq("25 MB")
    end
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner and/or report associations uncommented for create
  #   # expect(build(:image)).to be_valid
  #   pending("Requires functional owner/report factories and associations uncommented")
  # end
end
