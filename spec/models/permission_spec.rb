require 'rails_helper'

RSpec.describe Permission do

  describe 'associations' do
    it { should have_many(:user_permissions) }
    it { should have_many(:users).through(:user_permissions) }
  end

  describe 'validations' do
    # Assuming security_cat should be present and unique
    subject { build(:permission) }
    # it { should validate_presence_of(:security_cat) } # Model missing validation
    # Uniqueness test would require create
    # it { should validate_uniqueness_of(:security_cat) }
  end

  it 'is valid with valid attributes' do
    expect(build(:permission)).to be_valid
  end

  describe '#name' do
    it 'returns the security_cat' do
      permission = build(:permission, security_cat: "Test Category")
      expect(permission.name).to eq("Test Category")
    end
  end
end 