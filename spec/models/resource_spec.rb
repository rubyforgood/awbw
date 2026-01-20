require 'rails_helper'

RSpec.describe Resource do
  it { should have_many(:reports) } # As owner

  describe 'associations' do
    # Nested Attributes
    it { should accept_nested_attributes_for(:primary_asset).allow_destroy(true) }
    it { should accept_nested_attributes_for(:gallery_assets).allow_destroy(true) }
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

  # SearchCop
  describe 'search' do
    it 'returns correct resources when searching for the same random string' do
      random_string = Array.new(3) { SecureRandom.alphanumeric(6) }.join(' ')
      user = create(:user)

      resource1 = Resource.create!(title: "One", user: user, kind: "Handout", rhino_text: random_string)
      resource2 = Resource.create!(title: "Four", user: user, kind: "Handout", rhino_text: "Other")

      expect(Resource.count).to eq(2)

      results = Resource.search(random_string)
      expect(results).to contain_exactly(resource1)
    end
  end
end
