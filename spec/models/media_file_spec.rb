require 'rails_helper'

RSpec.describe MediaFile do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:report).optional }
    # it { should belong_to(:workshop).optional } # Fails: DB missing workshop_id column?
    it { should belong_to(:workshop_log).optional }
  end

  describe 'validations' do
    # Using shoulda matchers for Paperclip validations
    it { should have_attached_file(:file) }
    it { should validate_attachment_content_type(:file).allowing(MediaFile::FORM_FILE_CONTENT_TYPES).rejecting('text/plain', 'text/html') }
  end

  it 'is valid with valid attributes' do
    report = build_stubbed(:report)
    media_file = build(:media_file, report: report)
    expect(media_file).to be_valid
  end
end