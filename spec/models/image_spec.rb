require "rails_helper"

RSpec.describe Image do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { should belong_to(:owner) } # Polymorphic
    it { should belong_to(:report).optional } # Assuming report can be optional
  end

  describe "validations" do
    # Paperclip matchers (might require paperclip-matchers gem and setup)
    # it { should have_attached_file(:file) }
    # it { should validate_attachment_content_type(:file)
    #              .allowing('image/jpeg', 'image/png', 'image/gif')
    #              .rejecting('text/plain', 'application/pdf') }
    # Presence validation for file itself is usually handled by Paperclip/ActiveStorage

    it { should validate_content_type_of(:file).allowing(Image::ACCEPTED_CONTENT_TYPES) }
    it { should validate_content_type_of(:file).rejecting("text/plain", "text/xml") }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner and/or report associations uncommented for create
  #   # expect(build(:image)).to be_valid
  #   pending("Requires functional owner/report factories and associations uncommented")
  # end
end

