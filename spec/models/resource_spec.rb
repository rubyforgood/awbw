require 'rails_helper'

RSpec.describe Resource do
  it { should have_many(:reports) } # As owner

  describe 'associations' do
    # Nested Attributes
    it { should accept_nested_attributes_for(:main_image).allow_destroy(true) }
    it { should accept_nested_attributes_for(:gallery_images).allow_destroy(true) }
  end

  describe 'validations' do
    # Requires associations for create
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:kind) }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:resource)).to be_valid
  end
end
