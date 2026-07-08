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

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner and/or report associations uncommented for create
  #   # expect(build(:image)).to be_valid
  #   pending("Requires functional owner/report factories and associations uncommented")
  # end

  describe ".search" do
    let(:workshop) { create(:workshop) }
    let!(:titled)   { create(:primary_asset, title: "Sunset painting") }
    let!(:attached) { create(:gallery_asset, :with_file, title: "no match", owner: workshop) }
    let!(:other)    { create(:primary_asset, title: "Unrelated") }

    it "returns everything when the query is blank" do
      expect(Asset.search(nil)).to include(titled, attached, other)
    end

    it "matches on title" do
      expect(Asset.search("sunset")).to contain_exactly(titled)
    end

    it "matches on the attached filename" do
      expect(Asset.search("missing.png")).to contain_exactly(attached)
    end

    it "matches on the owner type it's attached to" do
      expect(Asset.search("Workshop")).to contain_exactly(attached)
    end
  end

  describe ".present_owner_types" do
    it "lists the distinct owner types present" do
      create(:primary_asset, owner: create(:workshop))
      create(:gallery_asset, owner: create(:story))

      expect(Asset.present_owner_types).to contain_exactly("Story", "Workshop")
    end
  end
end
