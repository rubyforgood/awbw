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

    it "matches on the owner record's title" do
      befriending = create(:workshop, title: "Befriending")
      other = create(:workshop, title: "Something else")
      wanted = create(:primary_asset, title: "no match", owner: befriending)
      create(:primary_asset, title: "no match", owner: other)

      expect(Asset.search("Befriending")).to contain_exactly(wanted)
    end

    it "matches on the owner record's name (name-column owners)" do
      variation = create(:workshop_variation, name: "Watercolor calm")
      wanted = create(:primary_asset, title: "no match", owner: variation)

      expect(Asset.search("Watercolor")).to contain_exactly(wanted)
    end
  end

  describe ".present_owner_types" do
    it "lists the distinct owner types present" do
      create(:primary_asset, owner: create(:workshop))
      create(:gallery_asset, owner: create(:story))

      expect(Asset.present_owner_types).to contain_exactly("Story", "Workshop")
    end
  end

  describe ".attached_to_hidden_resource" do
    it "returns only assets attached to a hidden-from-search resource" do
      hidden_resource = create(:resource, hidden_from_search: true)
      shown_resource  = create(:resource, hidden_from_search: false)
      on_hidden = create(:primary_asset, owner: hidden_resource)
      create(:primary_asset, owner: shown_resource)
      create(:primary_asset, owner: create(:workshop))

      expect(Asset.attached_to_hidden_resource).to contain_exactly(on_hidden)
    end
  end

  describe ".present_content_types" do
    it "lists the distinct attached-file content types present" do
      create(:primary_asset, :with_file)
      create(:gallery_asset, :with_pdf)
      create(:primary_asset) # no attachment -- excluded

      expect(Asset.present_content_types).to contain_exactly("application/pdf", "image/png")
    end
  end
end
