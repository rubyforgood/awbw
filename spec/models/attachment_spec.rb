require "rails_helper"

RSpec.describe Attachment do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { should belong_to(:owner) } # Polymorphic
  end

  describe "validations" do
    # Paperclip matchers (might require paperclip-matchers gem and setup)
    # it { should have_attached_file(:file) }
    # it { should validate_attachment_content_type(:file)
    #              .allowing('application/pdf', 'application/msword', 'image/gif', 'image/jpeg', 'image/png')
    #              .rejecting('text/plain', 'text/xml') }

    # Basic presence test if needed (though Paperclip handles some)
    # subject { build(:attachment, owner: create(:user)) } # Requires owner for validity
    # it { should validate_presence_of(:owner) } # Testing polymorphic presence can be tricky

    it { should validate_content_type_of(:file).allowing(Attachment::ACCEPTED_CONTENT_TYPES) }
    it { should validate_content_type_of(:file).rejecting("text/plain", "text/xml") }
  end

  # it 'is valid with an owner' do
  #   # Note: Factory needs an owner to be valid for create
  #   expect(build(:attachment, owner: create(:user))).to be_valid
  # end
end

