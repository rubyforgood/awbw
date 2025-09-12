require 'rails_helper'

RSpec.describe BookmarkAnnotation do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:bookmark) }
  end

  it 'is valid with valid attributes' do
    bookmark = build_stubbed(:bookmark)
    bookmark_annotation = build(:bookmark_annotation, bookmark: bookmark)
    expect(bookmark_annotation).to be_valid
  end
end